import 'dart:async';
import 'dart:convert';

// Bloc
import 'package:psifos_mobile_crypto/crypto/ecc/ec_keypair/export.dart';

import 'trustee_state.dart';
import 'trustee_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Services
import 'package:psifos_mobile_app/services/api.dart';

// Secure storage
import 'package:psifos_mobile_app/utils/secure_storage.dart';

// Crypto 
import 'package:pointycastle/ecc/curves/secp521r1.dart';
import 'package:psifos_mobile_crypto/psifos/trustee/export.dart';
import 'package:psifos_mobile_crypto/crypto/ecc/ec_dsa/export.dart';
import 'package:psifos_mobile_crypto/crypto/modp/rsa/export.dart';

class TrusteeBloc extends Bloc<TrusteeEvent, TrusteeState> {
  final ApiService apiService;
  
  late String electionShortName;
  late String trusteeName;
  
  late int participantId;
  late String randomness;
  late Map<String, dynamic> egParams;

  // TODO: replace by API provided params
  final domainParams = ECCurve_secp521r1();
  final threshold = 2;
  final numParticipants = 3;

  final secureStorage = const SecureStorage();
  final StreamController<int> _trusteeStepController = StreamController<int>();

  TrusteeBloc({required this.apiService}) : super(const TrusteeInitial()) {
    on<InitialDataLoaded>(_onInitialDataLoaded);
    on<CertGenerated>(_onCertGenerated);
    on<TrusteeSynchronized>(_onTrusteeSynchronized);
    on<TallyDecrypted>(_onTallyDecrypted);
  }

  Future<void> _onInitialDataLoaded(
      InitialDataLoaded event, Emitter<TrusteeState> emit) async {
    // Retrieve election short name and trustee name
    electionShortName = event.electionShortName;
    trusteeName = event.trusteeName;
    print("electionShortName: $electionShortName");
    print("trusteeName: $trusteeName");

    // Set election short name and trustee name in ApiService
    apiService.setElectionShortName(electionShortName);
    apiService.setTrusteeName(trusteeName);

    // Make HTTP GET request to retrieve participant_id
    await apiService.getParticipantId().then((value) => participantId = value);

    // Make HTTP GET request to retrieve eg_params
    await apiService.getEgParams().then((value) => egParams = value);

    // Make HTTP GET request to retrieve randomness
    await apiService.getRandomness().then((value) => randomness = value);

    print("participantId: $participantId");

    // Transition state machine to key generation state
    emit(const TrusteeKeyGeneration());
  }

  void _onCertGenerated(
      CertGenerated event, Emitter<TrusteeState> emit) async {
    
    // Generate signature keys
    final signatureKeyPair = ECDSA.generateKeyPair(domainParams);
    final sigPublicKey = signatureKeyPair.publicKey;
    final sigPrivateKey = signatureKeyPair.privateKey;

    // Generate encryption keys
    final encryptionKeyPair = RSA.generateKeyPair();
    final encPublicKey = encryptionKeyPair.publicKey;
    final encPrivateKey = encryptionKeyPair.privateKey;

    // Bundle keys into a JSON and store it using Secure Storage
    final keyPairs = json.encode({
      "encryption": {
        "public_key": encPublicKey.toJson(),
        "private_key": encPrivateKey.toJson()
      },
      "signature": {
        "public_key": sigPublicKey.toJson(),
        "private_key": sigPrivateKey.toJson()
      },
    });
    await secureStorage.write(namespace: electionShortName, key: 'keyPairs', value: keyPairs);

    // Certificate generation
    final certificate = Certificate.generateCertificate(sigPrivateKey, sigPublicKey, encPublicKey);

    // Push Key Generation data to endpoint
    await apiService.uploadCertificate(certificate).then((value) {
      if (value) {
        emit(const TrusteeSynchronization());
      }
    });
  }

  void _onTrusteeSynchronized(
      TrusteeSynchronized event, Emitter<TrusteeState> emit) async {
    int lastProcessedStep = 0;
    await for (var currentStep
        in apiService.pollKeyGenStep(_trusteeStepController)) {
      print('Current step: $currentStep');
      print('Last processed step: $lastProcessedStep');
      if (currentStep != null && lastProcessedStep != currentStep) {
        lastProcessedStep = currentStep;
        switch (currentStep) {
          case 1:
            _handleTrusteeSyncStep1();
            break;
          case 2:
            _handleTrusteeSyncStep2();
            break;
          case 3:
            _handleTrusteeSyncStep3();
            break;
          case 4:
            if (!emit.isDone) {
              _trusteeStepController.close();
              emit(const TrusteeTallyDecryption());
            }
            break;
          default:
            print('Unknown step: $currentStep');
            break;
        }
      } else {
        print('Waiting for participants to sync...');
      }
    }
  }

  void _onTallyDecrypted(
      TallyDecrypted event, Emitter<TrusteeState> emit) async {
    // Pull Partial Decryption data from endpoint
    Map<String, dynamic> decryptionData = await apiService.getPartialDecryptionData();

    // Retrieve secret from Secure Storage
    final encodedSecret = await secureStorage.read(namespace: electionShortName, key: 'secret');
    final secret = BigInt.parse(encodedSecret!);
    
    // partialDecryption = Decrypt(decryptionData, secret)
    final partialDecryption = {"decryptions": []};

    // Push Partial Decryption data to endpoint
    await apiService.postPartialDecryption(partialDecryption);
    emit(const TrusteeKeyGeneration());
  }

  // Trustee Synchronization

  void _handleTrusteeSyncStep1() async {
    // Pull step 1 data from endpoint
    Map<String, dynamic> inputStepData = await apiService.getTrusteeKeyGenStep1();

    // Store certificates using Secure Storage
    await secureStorage.write(namespace: electionShortName, key: 'certificates', value: json.encode(inputStepData));

    // Parse input step data and retrieve useful params
    final parsedInput = TrusteeSyncStep1.parseInput(inputStepData);
    final encryptionPublicKeys = parsedInput['encryption_public_keys']!;

    // Retrieve signature private key from Secure Storage
    final encodedKeyPairs = await secureStorage.read(namespace: electionShortName, key: 'keyPairs');
    final keyPairs = json.decode(encodedKeyPairs!);
    final sigPrivateKey = keyPairs['signature']['private_key'];
    ECPrivateKey signaturePrivateKey = ECPrivateKey.fromJson(sigPrivateKey, domainParams);

    // Handle trustee sync step 1
    final outputStepData = TrusteeSyncStep1.handle(signaturePrivateKey, encryptionPublicKeys, domainParams, threshold, numParticipants);

    // Push step 1 data to endpoint
    await apiService.postTrusteeKeyGenStep1(outputStepData);
  }

  void _handleTrusteeSyncStep2() async {
    // Pull step 2 data from endpoint
    Map<String, dynamic> inputStepData = await apiService.getTrusteeKeyGenStep2();
      
    // Retrieve key pairs from Secure Storage
    final encodedKeyPairs = await secureStorage.read(namespace: electionShortName, key: 'keyPairs');
    final keyPairs = json.decode(encodedKeyPairs!);

    // Retrieve certificates from Secure Storage
    final encodedCertificates = await secureStorage.read(namespace: electionShortName, key: 'certificates');
    final certificates = json.decode(encodedCertificates!);

    // Parse input step data and retrieve useful params
    final parsedInput = TrusteeSyncStep2.parseInput(keyPairs, certificates, inputStepData);
    final encryptionPrivateKey = parsedInput['encryption_private_key']!;
    final signaturePrivateKey = parsedInput['signature_private_key']!;
    final signaturePublicKeys = parsedInput['signature_public_keys']!;
    final signedEncryptedShares = parsedInput['signed_encrypted_shares']!;
    final signedBroadcasts = parsedInput['signed_broadcasts']!;

    // Handle trustee sync step 2
    final outputStepData = TrusteeSyncStep2.handle(encryptionPrivateKey, signaturePrivateKey, signaturePublicKeys, signedEncryptedShares, signedBroadcasts, threshold, numParticipants, participantId);

    // Push step 2 data to endpoint
    await apiService.postTrusteeKeyGenStep2(outputStepData);
  }

  void _handleTrusteeSyncStep3() async {
    // Pull step 3 data from endpoint
    Map<String, dynamic> inputStepData = await apiService.getTrusteeKeyGenStep3();
    
    // Parse input step data and retrieve useful params
    final recvShares = TrusteeSyncStep3.parseInput(inputStepData);

    // Handle trustee sync step 3
    final outputStepData = TrusteeSyncStep3.handle(recvShares, threshold, numParticipants, participantId);
    
    // Store final secret using Secure Storage
    final secret = outputStepData['secret']!;
    await secureStorage.write(namespace: electionShortName, key: 'secret', value: secret);

    // Push step 3 data to endpoint
    final verificationKey = {'verification_key': outputStepData['verification_key']!};
    await apiService.postTrusteeKeyGenStep3(verificationKey);
  }
}
