import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final String electionShortName;
  final String trusteeCookie;
  final String trusteeUUID;

  final int pollingInterval = 5;

  const ApiService({
    required this.baseUrl,
    required this.electionShortName,
    required this.trusteeCookie,
    required this.trusteeUUID,
  });

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
      print(e);
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

  Future<bool> uploadPublicKey(String publicKey) async {
    var uploadPublicKey = await http.post(
      Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/upload-pk'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'session=$trusteeCookie'
      },
      body: json.encode({'public_key_json': publicKey}),
    );
    return uploadPublicKey.statusCode == 200;
  }

  Future<bool> privateKeyValidated(String privateKey) async {
    var uploadPublicKey = await http.post(
      Uri.parse(
          '$baseUrl/$electionShortName/trustee/$trusteeUUID/private-key-validated'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'session=$trusteeCookie'
      },
    );
    return uploadPublicKey.statusCode == 200;
  }

  // Trustee Sync

  Stream<int?> pollTrusteeStep(
      StreamController<int> trusteeStepController) async* {
    while (true) {
      await Future.delayed(Duration(seconds: pollingInterval));
      final response = await http.get(Uri.parse(
          '$baseUrl/$electionShortName/trustee/$trusteeUUID/get-step'));

      if (response.statusCode == 200) {
        int trusteeStep = json.decode(response.body)["status"];
        yield trusteeStep;
        if (trusteeStep == 4) {
          break;
        }
      }
    }
  }

  Future<String> getTrusteeSyncStep1() async {
    var stepResponse = await http.get(
      Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/step-1'),
      headers: {'Cookie': 'session=$trusteeCookie'},
    );

    if (stepResponse.statusCode == 200) {
      return json.decode(stepResponse.body)["certificates"];
    } else {
      return "Error retrieving step 1 data.";
    }
  }

  Future<bool> postTrusteeSyncStep1(String coefficients, String points) async {
    var stepResponse = await http.post(
        Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/step-1'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session=$trusteeCookie'
        },
        body: json.encode({
          "coefficients": coefficients,
          "points": points,
        }));
    return stepResponse.statusCode == 200;
  }

  Future<Map<String, dynamic>> getTrusteeSyncStep2() async {
    var stepResponse = await http.get(
      Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/step-2'),
      headers: {'Cookie': 'session=$trusteeCookie'},
    );

    if (stepResponse.statusCode == 200) {
      return json.decode(stepResponse.body);
    } else {
      return {
        "status_code": stepResponse.statusCode.toString(),
        "error": "Error retrieving step 2 data.",
      };
    }
  }

  Future<bool> postTrusteeSyncStep2(String acknowledgements) async {
    var stepResponse = await http.post(
        Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/step-2'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session=$trusteeCookie'
        },
        body: json.encode({
          "acknowledgements": acknowledgements,
        }));
    return stepResponse.statusCode == 200;
  }

  Future<Map<String, dynamic>> getTrusteeSyncStep3() async {
    var stepResponse = await http.get(
      Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/step-3'),
      headers: {'Cookie': 'session=$trusteeCookie'},
    );

    if (stepResponse.statusCode == 200) {
      return json.decode(stepResponse.body);
    } else {
      return {
        "status_code": stepResponse.statusCode.toString(),
        "error": "Error retrieving step 3 data.",
      };
    }
  }

  Future<bool> postTrusteeSyncStep3(String verificationKey) async {
    var stepResponse = await http.post(
        Uri.parse('$baseUrl/$electionShortName/trustee/$trusteeUUID/step-3'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session=$trusteeCookie'
        },
        body: json.encode({
          "verification_key": verificationKey,
        }));
    return stepResponse.statusCode == 200;
  }

  Future<Map<String, dynamic>> getPartialDecryptionData() async {
    var response = await http.get(
      Uri.parse(
          '$baseUrl/$electionShortName/trustee/$trusteeUUID/decrypt-and-prove'),
      headers: {'Cookie': 'session=$trusteeCookie'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        "status_code": response.statusCode.toString(),
        "error": "Error retrieving decryption data.",
      };
    }
  }

  Future<bool> postPartialDecryption(
      List<Map<String, dynamic>> partialDecryption) async {
    var response = await http.post(
        Uri.parse(
            '$baseUrl/$electionShortName/trustee/$trusteeUUID/decrypt-and-prove'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session=$trusteeCookie'
        },
        body: json.encode({'decryptions': partialDecryption}));
    return response.statusCode == 200;
  }
}
