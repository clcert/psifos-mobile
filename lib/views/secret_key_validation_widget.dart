import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psifos_mobile_app/views/trustee_stage_widget.dart';
import '../bloc/trustee_bloc.dart';
import '../bloc/trustee_event.dart';

class PrivateKeyValidationWidget extends StatelessWidget {
  const PrivateKeyValidationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the TrusteeBloc instance and its state variables
    final TrusteeBloc trusteeBloc = context.read<TrusteeBloc>();

    // Build the widget based on the Bloc's state variables
    return TrusteeStageWidget(
        titleText: "Stage 2: Private Key Validation",
        buttonText: "Validate Private Key",
        onPressed: _onButtonPressed,
        trusteeBloc: trusteeBloc);
  }

  void _onButtonPressed(TrusteeBloc trusteeBloc) {
    // TODO: Implement Private Key Validation logic

    // Wait for 5 seconds before transitioning
    Future.delayed(const Duration(seconds: 5), () {
      trusteeBloc.add(PrivateKeyValidated());
    });
  }
}
