import 'package:flutter/material.dart';
import 'package:psifos_mobile_app/bloc/trustee_bloc.dart';

class TrusteeStageWidget extends StatelessWidget {
  final String titleText;
  final String buttonText;
  final Function(TrusteeBloc) onPressed;
  final TrusteeBloc trusteeBloc;

  const TrusteeStageWidget(
      {super.key,
      required this.titleText,
      required this.buttonText,
      required this.onPressed,
      required this.trusteeBloc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFBD59), // Hex color #FFBD59
            border: Border(
              bottom: BorderSide(
                color: Colors.black,
                width: 4.0,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Trustee Prototype',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        margin: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max, // Use minimum height
          children: <Widget>[
            Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                )),
            const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam posuere ex sem, vitae pretium mi vehicula ac. Nulla pulvinar eleifend purus, laoreet luctus erat blandit vitae. Ut eget faucibus mauris. In iaculis dolor semper, ultrices turpis quis, ullamcorper sapien. Aliquam consequat quis diam in varius.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                )),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: () => onPressed(trusteeBloc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFBD59),
                  side: const BorderSide(color: Colors.black, width: 3),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
