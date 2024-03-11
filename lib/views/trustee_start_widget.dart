import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/trustee_bloc.dart';
import '../bloc/trustee_event.dart';

class TrusteeStartWidget extends StatelessWidget {
  final String titleText = "Trustee Start";
  final String buttonText = "Start";

  const TrusteeStartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the TextEditingControllers
    final electionShortNameController = TextEditingController();
    final trusteeNameController = TextEditingController();

    // Access the TrusteeBloc instance
    final TrusteeBloc trusteeBloc = context.read<TrusteeBloc>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFFFBD59),
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
            title: Text('Trustee Prototype',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(20.0),
        margin: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Election short name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: electionShortNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter Election short name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Trustee Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: trusteeNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter Trustee Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: () => _onButtonPressed(trusteeBloc,
                    electionShortNameController, trusteeNameController),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFBD59),
                  side: BorderSide(color: Colors.black, width: 3),
                  textStyle: TextStyle(fontWeight: FontWeight.bold),
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  buttonText,
                  style: TextStyle(
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

  void _onButtonPressed(
      TrusteeBloc trusteeBloc,
      TextEditingController electionShortNameController,
      TextEditingController trusteeNameController) {
    // Retrieve values from the text input fields
    String electionShortName = electionShortNameController.text;
    String trusteeName = trusteeNameController.text;

    // Add your event with the retrieved data
    trusteeBloc.add(InitialDataLoaded(
        electionShortName: electionShortName, trusteeName: trusteeName));
  }
}
