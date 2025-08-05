import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../main.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _chatEndpoint = '/chat/completions';
  
  // Get API key from environment variables
  static String get _apiKey {
    final key = EnvironmentConfig.GROQ_API_KEY;
    if (key.isEmpty) {
      throw GroqException(
        'GROQ_API_KEY not found in environment variables. '
        'Please add your Groq API key to the EnvironmentConfig class.'
      );
    }
    return key;
  }
  
  // Available Groq models - choose based on your needs
  static const String _modelLlama370B = 'llama-3.1-70b-instant';
  static const String _modelLlama38B = 'llama-3.1-8b-instant';
  static const String _modelMixtral = 'mixtral-8x7b-32768';
  static const String _modelGemma = 'gemma-7b-it';
  
  // Get default model from environment or use fallback
  static String get _defaultModel {
    return EnvironmentConfig.GROQ_MODEL;
  }
  
  final http.Client _client;
  final String _model;
  final int _maxTokens;
  final double _temperature;
  final Duration _timeout;
  
  GroqService({
    http.Client? client,
    String? model,
    int maxTokens = 1024,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _model = model ?? _defaultModel,
       _maxTokens = maxTokens,
       _temperature = temperature,
       _timeout = timeout;

  /// Send a message to Groq AI and get response
  Future<String> sendMessage(String message, {
    List<Map<String, String>>? conversationHistory,
    String? systemPrompt,
  }) async {
    try {
      // Verify API key is available
      final apiKey = _apiKey; // This will throw if not found
      
      final messages = _buildMessages(message, conversationHistory, systemPrompt);
      final response = await _makeRequest(messages);
      
      return _extractResponseContent(response);
    } catch (e) {
      if (kDebugMode) {
        print('GroqService Error: $e');
      }
      rethrow;
    }
  }

  /// Send a message with structured conversation history
  Future<String> sendChatMessage({
    required String userMessage,
    List<ChatMessage>? history,
    String? systemMessage,
    String? model,
  }) async {
    try {
      final messages = <Map<String, String>>[];
      
      // Add system message if provided
      if (systemMessage != null && systemMessage.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemMessage,
        });
      }
      
      // Add conversation history
      if (history != null && history.isNotEmpty) {
        for (final message in history) {
          messages.add({
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
          });
        }
      }
      
      // Add current user message
      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      final response = await _makeRequest(messages, model: model);
      return _extractResponseContent(response);
    } catch (e) {
      if (kDebugMode) {
        print('GroqService Chat Error: $e');
      }
      rethrow;
    }
  }

  /// Check if the service is available
  Future<bool> checkConnection() async {
    try {
      await sendMessage('Hello', conversationHistory: []);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('GroqService Connection Check Failed: $e');
      }
      return false;
    }
  }

  /// Get available models
  List<String> getAvailableModels() {
    return [
      _modelLlama370B,
      _modelLlama38B,
      _modelMixtral,
      _modelGemma,
    ];
  }

  /// Get model information
  Map<String, String> getModelInfo(String model) {
    switch (model) {
      case _modelLlama370B:
        return {
          'name': 'Llama 3.1 70B',
          'description': 'Most capable model, best for complex reasoning',
          'context': '128K tokens',
        };
      case _modelLlama38B:
        return {
          'name': 'Llama 3.1 8B',
          'description': 'Fast and efficient, good for simple tasks',
          'context': '128K tokens',
        };
      case _modelMixtral:
        return {
          'name': 'Mixtral 8x7B',
          'description': 'Good balance of speed and capability',
          'context': '32K tokens',
        };
      case _modelGemma:
        return {
          'name': 'Gemma 7B',
          'description': 'Lightweight model for basic conversations',
          'context': '8K tokens',
        };
      default:
        return {
          'name': 'Unknown Model',
          'description': 'Model information not available',
          'context': 'Unknown',
        };
    }
  }

  /// Get current configuration info
  Map<String, dynamic> getConfigInfo() {
    return {
      'model': _model,
      'maxTokens': _maxTokens,
      'temperature': _temperature,
      'timeout': _timeout.inSeconds,
      'hasApiKey': _apiKey.isNotEmpty,
      'debugMode': EnvironmentConfig.DEBUG_MODE == 'true',
    };
  }

  /// Build messages array for API request
  List<Map<String, String>> _buildMessages(
    String message,
    List<Map<String, String>>? conversationHistory,
    String? systemPrompt,
  ) {
    final messages = <Map<String, String>>[];
    
    // Add system prompt if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
    
    // Add conversation history
    if (conversationHistory != null) {
      messages.addAll(conversationHistory);
    }
    
    // Add current message
    messages.add({
      'role': 'user',
      'content': message,
    });
    
    return messages;
  }

  /// Make HTTP request to Groq API
  Future<Map<String, dynamic>> _makeRequest(
    List<Map<String, String>> messages, {
    String? model,
  }) async {
    final url = Uri.parse('$_baseUrl$_chatEndpoint');
    
    final requestBody = {
      'model': model ?? _model,
      'messages': messages,
      'max_tokens': _maxTokens,
      'temperature': _temperature,
      'stream': false,
    };

    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'User-Agent': '${EnvironmentConfig.APP_NAME}/${EnvironmentConfig.APP_VERSION}',
    };

    if (kDebugMode && EnvironmentConfig.DEBUG_MODE == 'true') {
      print('GroqService Request: ${requestBody['model']} - ${messages.length} messages');
    }

    final response = await _client
        .post(
          url,
          headers: headers,
          body: jsonEncode(requestBody),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (kDebugMode && EnvironmentConfig.DEBUG_MODE == 'true') {
        final usage = data['usage'] as Map<String, dynamic>?;
        if (usage != null) {
          print('GroqService Usage: ${usage['total_tokens']} tokens');
        }
      }
      
      return data;
    } else {
      final errorBody = response.body;
      final statusCode = response.statusCode;
      
      if (kDebugMode) {
        print('GroqService HTTP Error: $statusCode - $errorBody');
      }
      
      throw GroqException(_getErrorMessage(statusCode, errorBody));
    }
  }

  /// Extract response content from API response
  String _extractResponseContent(Map<String, dynamic> response) {
    try {
      final choices = response['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw GroqException('No response choices received from Groq API');
      }
      
      final firstChoice = choices[0] as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      
      if (message == null) {
        throw GroqException('No message in response from Groq API');
      }
      
      final content = message['content'] as String?;
      if (content == null || content.isEmpty) {
        throw GroqException('Empty response content from Groq API');
      }
      
      return content.trim();
    } catch (e) {
      if (e is GroqException) rethrow;
      throw GroqException('Failed to parse Groq API response: $e');
    }
  }

  /// Get user-friendly error message based on status code
  String _getErrorMessage(int statusCode, String errorBody) {
    try {
      final errorData = jsonDecode(errorBody) as Map<String, dynamic>;
      final error = errorData['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      
      if (message != null) {
        return message;
      }
    } catch (e) {
      // Fall through to default messages
    }
    
    switch (statusCode) {
      case 400:
        return 'Bad request. Please check your input and try again.';
      case 401:
        return 'Invalid API key. Please check your Groq API key in the .env file.';
      case 403:
        return 'Access forbidden. Please check your API key permissions.';
      case 429:
        return 'Rate limit exceeded. Please wait a moment and try again.';
      case 500:
        return 'Groq server error. Please try again later.';
      case 502:
      case 503:
      case 504:
        return 'Groq service temporarily unavailable. Please try again later.';
      default:
        return 'Request failed with status $statusCode. Please try again.';
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

/// Custom exception class for Groq service errors
class GroqException implements Exception {
  final String message;
  
  const GroqException(this.message);
  
  @override
  String toString() => 'GroqException: $message';
}

/// Chat message model for structured conversations
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Service configuration class
class GroqConfig {
  static String get defaultSystemPrompt {
    return '''You are a professional AI medical assistant. Your responsibilities:

MEDICAL ASSISTANCE:
- Provide helpful medical information with appropriate disclaimers
- Always remind users you're an AI and cannot replace professional medical diagnosis
- For emergencies, immediately recommend calling emergency services
- Give general health advice while emphasizing the need for professional consultation

APPOINTMENT BOOKING:
- When users want to book appointments, respond EXACTLY with: "BOOK_APPOINTMENT_TRIGGER"
- Don't add any other text when triggering booking

COMMUNICATION STYLE:
- Be empathetic, professional, and caring
- Keep responses concise but informative
- Use medical terminology appropriately but explain complex terms
- Always prioritize patient safety

LIMITATIONS:
- You cannot diagnose medical conditions
- You cannot prescribe medications
- You cannot replace emergency medical services
- Always recommend consulting healthcare professionals for serious concerns''';
  }

  static Map<String, dynamic> get defaultSettings {
    return {
      'model': EnvironmentConfig.GROQ_MODEL,
      'maxTokens': 1024,
      'temperature': 0.7,
      'timeout': 30,
    };
  }
}

/// Usage example and helper methods
class GroqServiceHelper {
  static GroqService createMedicalAssistant() {
    final settings = GroqConfig.defaultSettings;
    return GroqService(
      model: settings['model'] as String,
      maxTokens: settings['maxTokens'] as int,
      temperature: settings['temperature'] as double,
      timeout: Duration(seconds: settings['timeout'] as int),
    );
  }
  
  static GroqService createFastAssistant() {
    return GroqService(
      model: 'llama-3.1-8b-instant',
      maxTokens: 512,
      temperature: 0.5,
      timeout: const Duration(seconds: 15),
    );
  }
  
  static Future<bool> testConnection() async {
    final service = createFastAssistant();
    try {
      final isConnected = await service.checkConnection();
      service.dispose();
      return isConnected;
    } catch (e) {
      service.dispose();
      return false;
    }
  }
  
  static Map<String, dynamic> getEnvironmentInfo() {
    return {
      'hasGroqApiKey': EnvironmentConfig.GROQ_API_KEY.isNotEmpty,
      'groqModel': EnvironmentConfig.GROQ_MODEL,
      'debugMode': EnvironmentConfig.DEBUG_MODE == 'true',
      'appName': EnvironmentConfig.APP_NAME,
      'appVersion': EnvironmentConfig.APP_VERSION,
    };
  }
}