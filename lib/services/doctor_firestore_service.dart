import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DoctorFirestoreService {
  static Future<String?> addDoctor(Map<String, dynamic> doctorData) async {
    try {
      final docRef = await FirebaseFirestore.instance.collection('doctors').add(doctorData);
      return docRef.id;
    } catch (e) {
      print('Error adding doctor: $e');
      return null;
    }
  }



  /// Uploads a doctor profile image to Cloudinary and returns the public URL
  /// Note: This requires valid Cloudinary credentials
  static Future<String?> uploadImageToCloudinary(File imageFile) async {
    const String cloudName = 'dy0b6ppru'; 
    const String apiKey = '268478538369193'; 
    const String apiSecret = 'hGf0WPDZE3Zr_pv1_lFRnJx3W4g'; 
    
    final Uri url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    
    try {
      print('Uploading image to Cloudinary: ${imageFile.path}');
      print('File exists: ${await imageFile.exists()}');
      print('File size: ${await imageFile.length()} bytes');
      
      // Create multipart request
      var request = http.MultipartRequest('POST', url);
      
      // Add file
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: 'doctor_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);
      
      // Add form fields for signed upload
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final publicId = 'doctor_${DateTime.now().millisecondsSinceEpoch}';
      
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['folder'] = 'doctor_profiles';
      request.fields['public_id'] = publicId;
      
      // Generate signature for signed upload
      final params = {
        'timestamp': timestamp,
        'folder': 'doctor_profiles',
        'public_id': publicId,
      };
      
      // Sort parameters alphabetically
      final sortedParams = params.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      final paramString = sortedParams.map((e) => '${e.key}=${e.value}').join('&');
      
      // Generate signature
      final signature = _generateSignature(paramString, apiSecret);
      request.fields['signature'] = signature;
      
      // Send request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      print('Cloudinary response status: ${response.statusCode}');
      print('Cloudinary response: $responseData');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        final imageUrl = data['secure_url'];
        print('Cloudinary upload success: $imageUrl');
        return imageUrl;
      } else {
        print('Cloudinary upload failed: ${response.statusCode} $responseData');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      print('Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Main method to upload image - uses Cloudinary
  static Future<String?> uploadImage(File imageFile) async {
    // Use Cloudinary for image upload
    print('Uploading image to Cloudinary...');
    String? imageUrl = await uploadImageToCloudinary(imageFile);
    
    if (imageUrl != null) {
      print('Successfully uploaded image to Cloudinary: $imageUrl');
      return imageUrl;
    }
    
    print('Cloudinary upload failed');
    return null;
  }

  /// Generate signature for Cloudinary signed uploads
  static String _generateSignature(String paramString, String apiSecret) {
    final signature = '$paramString$apiSecret';
    final bytes = utf8.encode(signature);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }
} 