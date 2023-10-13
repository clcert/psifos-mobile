import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:psifos_mobile_app/services/api.dart';
import 'bloc/trustee_bloc.dart';
import 'bloc/trustee_event.dart';
import 'bloc/trustee_state.dart';
import 'views/key_generation_widget.dart';
import 'views/secret_key_validation_widget.dart';
import 'views/synchronization_widget.dart';
import 'views/partial_decryption_widget.dart';

void main() async {
  await dotenv.load(); // Load environment variables
  String electionShortName = dotenv.env['ELECTION_SHORT_NAME']!;
  String trusteeCookie = dotenv.env['TRUSTEE_COOKIE']!;
  String trusteeUUID = dotenv.env['TRUSTEE_UUID']!;
  // set baseUrl depending if iOS or Android
  String baseUrl = Platform.isAndroid
      ? dotenv.env['ANDROID_LOCAL_API']!
      : dotenv.env['IOS_LOCAL_API']!;

  final apiService = ApiService(
      baseUrl: baseUrl,
      electionShortName: electionShortName,
      trusteeCookie: trusteeCookie,
      trusteeUUID: trusteeUUID);

  final trusteeBloc = TrusteeBloc(apiService: apiService);
  trusteeBloc.add(InitialDataLoaded());

  runApp(
    BlocProvider.value(
      value: trusteeBloc,
      child: const MaterialApp(
        home: Scaffold(body: TrusteeScreen()),
      ),
    ),
  );
}

class TrusteeScreen extends StatelessWidget {
  const TrusteeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrusteeBloc, TrusteeState>(
      builder: (context, state) {
        switch (state.status) {
          case TrusteeStatus.keyPairGeneration:
            return const KeyGenerationWidget();
          case TrusteeStatus.privateKeyValidation:
            return const PrivateKeyValidationWidget();
          case TrusteeStatus.synchronization:
            return const SynchronizationWidget();
          case TrusteeStatus.tallyDecryption:
            return const PartialDecryptionWidget();
          default:
            return const CircularProgressIndicator(); // Loading
        }
      },
    );
  }
}
