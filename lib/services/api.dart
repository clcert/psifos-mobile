import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final String trusteeCookie;
  late String trusteeName;
  late String electionShortName;

  final int pollingInterval = 5;

  ApiService({
    required this.baseUrl,
    required this.trusteeCookie,
  });

  // Getters and setters for electionShortName and trusteeName
  void setElectionShortName(String electionShortName) {
    this.electionShortName = electionShortName;
  }
  void setTrusteeName(String trusteeName) {
    this.trusteeName = trusteeName;
  }


  Future<int> getParticipantId() async {
    var participantIdResponse = await http.get(
      Uri.parse(
          '$baseUrl/$electionShortName/trustee/$trusteeName/get-participant-id'),
      headers: {'Cookie': 'session=$trusteeCookie'},
    );

    if (participantIdResponse.statusCode == 200) {
      return json.decode(participantIdResponse.body)["participant_id"];
    } else {
      return -1;
    }
  }

  Future<Map<String, dynamic>> getEgParams() async {
    try {
      var egParamsResponse = await http.get(
        Uri.parse('$baseUrl/$electionShortName/get-eg-params'),
        headers: {'Cookie': 'session=$trusteeCookie'},
      );

      if (egParamsResponse.statusCode == 200) {
        return json.decode(egParamsResponse.body);
      } else {
        return {
          "status_code": egParamsResponse.statusCode.toString(),
          "error": "Error retrieving eg_params.",
        };
      }
    } catch (e) {
      return {
        "status_code": "500",
        "error": "Error retrieving eg_params.",
      };
    }
  }

  Future<String> getRandomness() async {
    var randomnessResponse = await http.get(
      Uri.parse('$baseUrl/$electionShortName/get-randomness'),
      headers: {'Cookie': 'session=$trusteeCookie'},
    );

    if (randomnessResponse.statusCode == 200) {
      return json.decode(randomnessResponse.body)["randomness"];
    } else {
      return "error";
    }
  }

  Future<bool> uploadCertificate(Map<String, dynamic> cert) async {
    var uploadPublicKey = await http.post(
      Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeName/upload-cert'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'session=$trusteeCookie'
      },
      body: json.encode(cert),
    );
    return uploadPublicKey.statusCode == 200;
  }

  // Trustee Sync

  Stream<int?> pollKeyGenStep(
      StreamController<int> trusteeStepController) async* {
    while (true) {
      await Future.delayed(Duration(seconds: pollingInterval));
      final response = await http
          .get(Uri.parse('$baseUrl/$electionShortName/get-global-keygen-step'));

      if (response.statusCode == 200) {
        int trusteeStep = json.decode(response.body)["global_keygen_step"];
        yield trusteeStep;
        if (trusteeStep == 4) {
          break;
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getFromEndpoint(String endpoint) async {
    final url = Uri.parse('$baseUrl/$electionShortName/$endpoint');
    final response =
        await http.get(url, headers: {'Cookie': 'session=$trusteeCookie'});

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        "status_code": response.statusCode.toString(),
        "error": "Error retrieving $endpoint data.",
      };
    }
  }

  Future<bool> _postToEndpoint(
      String endpoint, Map<String, dynamic> stepData) async {
    final url = Uri.parse('$baseUrl/$electionShortName/$endpoint');
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session=$trusteeCookie'
        },
        body: json.encode(stepData));

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> getTrusteeKeyGenStep1() async {
    return await _getFromEndpoint('trustee/$trusteeName/step-1');
  }

  Future<bool> postTrusteeKeyGenStep1(Map<String, dynamic> stepData) async {
    return await _postToEndpoint('trustee/$trusteeName/step-1', stepData);
  }

  Future<Map<String, dynamic>> getTrusteeKeyGenStep2() async {
    return await _getFromEndpoint('trustee/$trusteeName/step-2');
  }

  Future<bool> postTrusteeKeyGenStep2(Map<String, dynamic> stepData) async {
    return await _postToEndpoint('trustee/$trusteeName/step-2', stepData);
  }

  Future<Map<String, dynamic>> getTrusteeKeyGenStep3() async {
    return await _getFromEndpoint('trustee/$trusteeName/step-3');
  }

  Future<bool> postTrusteeKeyGenStep3(Map<String, dynamic> stepData) async {
    return await _postToEndpoint('trustee/$trusteeName/step-3', stepData);
  }

  Future<Map<String, dynamic>> getPartialDecryptionData() async {
    return await _getFromEndpoint('trustee/$trusteeName/decrypt-and-prove');
  }

  Future<bool> postPartialDecryption(
      Map<String, dynamic> partialDecryption) async {
    var response = await http.post(
        Uri.parse(
            '$baseUrl/$electionShortName/trustee/$trusteeName/decrypt-and-prove'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session=$trusteeCookie'
        },
        body: json.encode(partialDecryption));
    return response.statusCode == 200;
  }
}
