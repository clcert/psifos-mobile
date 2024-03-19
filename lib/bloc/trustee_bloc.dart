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
import 'package:psifos_mobile_crypto/psifos/trustee/export.dart';
import 'package:psifos_mobile_crypto/crypto/ecc/ec_dsa/export.dart';
import 'package:psifos_mobile_crypto/crypto/modp/rsa/export.dart';
import 'package:pointycastle/ecc/api.dart' as ecc_api;

class TrusteeBloc extends Bloc<TrusteeEvent, TrusteeState> {
  final ApiService apiService;
  
  late String electionShortName;
  late String trusteeName;
  
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

    // Set election short name and trustee name in ApiService
    apiService.setElectionShortName(electionShortName);
    apiService.setTrusteeName(trusteeName);

    // Make HTTP GET request to retrieve participant_id
    int participantId = await apiService.getParticipantId();
    await secureStorage.write(namespace: electionShortName, key: 'participantId', value: participantId.toString());
    
    // Make HTTP GET request to retrieve election params
    Map<String, dynamic> keyGenParams = await apiService.getKeyGenParams();
    await secureStorage.write(namespace: electionShortName, key: 'keyGenParams', value: json.encode(keyGenParams));

    // Transition state machine to key generation state
    emit(const TrusteeKeyGeneration());
  }

  void _onCertGenerated(
      CertGenerated event, Emitter<TrusteeState> emit) async {
    final encodedKeyGenParams = await secureStorage.read(namespace: electionShortName, key: 'keyGenParams');
    final keyGenParams = json.decode(encodedKeyGenParams!);
    final curveName = keyGenParams["curve"];
    final domainParams = ecc_api.ECDomainParameters(curveName);
    
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
    // Read election params from Secure Storage
    final encodedKeyGenParams = await secureStorage.read(namespace: electionShortName, key: 'keyGenParams');
    final keyGenParams = json.decode(encodedKeyGenParams!);

    final curveName = keyGenParams["curve"];
    final domainParams = ecc_api.ECDomainParameters(curveName);

    final threshold = keyGenParams["threshold"];
    final numParticipants = keyGenParams["num_participants"];

    // Pull step 1 data from endpoint
    Map<String, dynamic> inputStepData = await apiService.getTrusteeKeyGenStep1();

    // Store certificates using Secure Storage
    await secureStorage.write(namespace: electionShortName, key: 'certificates', value: json.encode(inputStepData));

    // Parse input step data and retrieve useful params
    final parsedInput = TrusteeSyncStep1.parseInput(inputStepData, curveName);
    final encryptionPublicKeys = parsedInput['encryption_public_keys']!;

    // Retrieve signature private key from Secure Storage
    final encodedKeyPairs = await secureStorage.read(namespace: electionShortName, key: 'keyPairs');
    final keyPairs = json.decode(encodedKeyPairs!);
    final sigPrivateKey = keyPairs['signature']['private_key'];
    ECPrivateKey signaturePrivateKey = ECPrivateKey.fromJson(sigPrivateKey, domainParams);

    // Handle trustee sync step 1
    final outputStepData = TrusteeSyncStep1.handle(signaturePrivateKey, encryptionPublicKeys, curveName, threshold, numParticipants);

    // Push step 1 data to endpoint
    await apiService.postTrusteeKeyGenStep1(outputStepData);
  }

  void _handleTrusteeSyncStep2() async {
    // Read election params from Secure Storage
    final encodedKeyGenParams = await secureStorage.read(namespace: electionShortName, key: 'keyGenParams');
    final keyGenParams = json.decode(encodedKeyGenParams!);

    final curveName = keyGenParams["curve"];
    final threshold = keyGenParams["threshold"];
    final numParticipants = keyGenParams["num_participants"];

    // Retrieve participant ID from Secure Storage
    final encodedParticipantId = await secureStorage.read(namespace: electionShortName, key: 'participantId');
    final participantId = int.parse(encodedParticipantId!);

    // Pull step 2 data from endpoint
    Map<String, dynamic> inputStepData = await apiService.getTrusteeKeyGenStep2();

    // Store recv_shares using Secure Storage
    final recvShares = inputStepData['signed_encrypted_shares'];
    await secureStorage.write(namespace: electionShortName, key: 'recvShares', value: json.encode(recvShares));
      
    // Retrieve key pairs from Secure Storage
    final encodedKeyPairs = await secureStorage.read(namespace: electionShortName, key: 'keyPairs');
    final keyPairs = json.decode(encodedKeyPairs!);

    // Retrieve certificates from Secure Storage
    final encodedCertificates = await secureStorage.read(namespace: electionShortName, key: 'certificates');
    final certificates = json.decode(encodedCertificates!);

    // Parse input step data and retrieve useful params
    final parsedInput = TrusteeSyncStep2.parseInput(keyPairs, certificates, inputStepData, curveName);
    final encryptionPrivateKey = parsedInput['encryption_private_key']!;
    final signaturePrivateKey = parsedInput['signature_private_key']!;
    final signaturePublicKeys = parsedInput['signature_public_keys']!;
    final signedEncryptedShares = parsedInput['signed_encrypted_shares']!;
    final signedBroadcasts = parsedInput['signed_broadcasts']!;

    // Handle trustee sync step 2
    final outputStepData = TrusteeSyncStep2.handle(encryptionPrivateKey, signaturePrivateKey, signaturePublicKeys, signedEncryptedShares, signedBroadcasts, curveName, threshold, numParticipants, participantId);

    // Push step 2 data to endpoint
    await apiService.postTrusteeKeyGenStep2(outputStepData);
  }

  void _handleTrusteeSyncStep3() async {
    // Read election params from Secure Storage
    final encodedKeyGenParams = await secureStorage.read(namespace: electionShortName, key: 'keyGenParams');
    final keyGenParams = json.decode(encodedKeyGenParams!);

    final threshold = keyGenParams["threshold"];
    final curveName = keyGenParams["curve"];
    final numParticipants = keyGenParams["num_participants"];

    // Retrieve participant ID from Secure Storage
    final encodedParticipantId = await secureStorage.read(namespace: electionShortName, key: 'participantId');
    final participantId = int.parse(encodedParticipantId!);

    // Pull step 3 data from endpoint
    Map<String, dynamic> stepData = await apiService.getTrusteeKeyGenStep3();
    
    // Retrieve recvShares from Secure Storage
    final encodedRecvShares = await secureStorage.read(namespace: electionShortName, key: 'recvShares');
    final recvSharesJSON = json.decode(encodedRecvShares!);

    // Based on stepData and recvShares, make a Map to use as input.
    final inputStepData = {
      'recv_shares': recvSharesJSON,
      ...stepData
    };

    // Parse input step data and retrieve useful params
    final parsedInput = TrusteeSyncStep3.parseInput(inputStepData);
    final recvShares = parsedInput['recv_shares']!;

    // Handle trustee sync step 3
    final outputStepData = TrusteeSyncStep3.handle(recvShares, curveName, threshold, numParticipants, participantId);
    
    // Store final secret and verification_key using Secure Storage
    final secret = outputStepData['secret']!;
    final verificationKey = outputStepData['verification_key']!;
    await secureStorage.write(namespace: electionShortName, key: 'secret', value: secret);
    await secureStorage.write(namespace: electionShortName, key: 'verificationKey', value: verificationKey);

    // Push step 3 data to endpoint
    await apiService.postTrusteeKeyGenStep3({'verification_key': verificationKey});

    // Delete data from Secure Storage that is no longer needed
    await secureStorage.delete(namespace: electionShortName, key: 'recvShares');
    await secureStorage.delete(namespace: electionShortName, key: 'certificates');
  }
}
