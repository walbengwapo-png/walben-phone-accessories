import 'dart:io';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../errors/api_exception.dart';
import '../session/session.dart';

class ApiClient {
  ApiClient(this.tokens)
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
        ),
      );

  final TokenStore tokens;
  final Dio _dio;
  Future<bool>? _refreshing;

  Future<Response<dynamic>> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool public = false,
    bool retried = false,
    Options? options,
  }) async {
    try {
      final headers = <String, dynamic>{...?options?.headers};
      if (!public) {
        final access = await tokens.accessToken();
        if (access != null && access.isNotEmpty) {
          headers['Authorization'] = 'Bearer $access';
        }
      }
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: (options ?? Options()).copyWith(
          method: method,
          headers: headers,
        ),
      );
      return response;
    } on DioException catch (error) {
      final canRefresh =
          !public &&
          !retried &&
          error.response?.statusCode == 401 &&
          !path.startsWith('/auth/');
      if (canRefresh && await _refresh()) {
        return request(
          method,
          path,
          data: data,
          query: query,
          public: public,
          retried: true,
          options: options,
        );
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<bool> _refresh() async {
    _refreshing ??= _doRefresh();
    try {
      return await _refreshing!;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refresh = await tokens.refreshToken();
    if (refresh == null || refresh.isEmpty) {
      await tokens.clear();
      return false;
    }
    try {
      final response = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      final map = _map(response.data);
      final raw = _map(map['tokens'] ?? map['data']?['tokens'] ?? map['data']);
      final access = raw['access_token'] ?? raw['accessToken'];
      final rotated = raw['refresh_token'] ?? raw['refreshToken'];
      if (access is String && rotated is String) {
        await tokens.save(access, rotated);
        return true;
      }
    } catch (_) {
      // Fall through to clearing the session below.
    }
    await tokens.clear();
    return false;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

/// Validates the envelope and returns the raw map. Requires an explicit
/// `success` boolean. A missing/invalid flag is treated as malformed rather
/// than silently accepted.
Map<String, dynamic> envelopeMap(dynamic value) {
  if (value is! Map) {
    throw const ApiException(
      'The server returned an invalid response.',
      kind: ApiErrorKind.malformed,
    );
  }
  final map = Map<String, dynamic>.from(value);
  final success = map['success'];
  if (success == false) {
    throw ApiException(
      '${map['message'] ?? 'Request was not completed.'}',
      kind: ApiErrorKind.server,
    );
  }
  if (success is! bool || success != true) {
    throw const ApiException(
      'The server response is missing a valid success flag.',
      kind: ApiErrorKind.malformed,
    );
  }
  return map;
}

dynamic envelopeData(Response<dynamic> response) {
  final map = envelopeMap(response.data);
  return map.containsKey('data') ? map['data'] : map;
}

/// Extracts a list of row maps. Throws on a non-list payload instead of
/// silently turning malformed responses into empty states.
List<Map<String, dynamic>> mapList(dynamic value) {
  dynamic raw = value;
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    raw =
        m['items'] ??
        m['data'] ??
        m['products'] ??
        m['orders'] ??
        m['categories'] ??
        m['brands'] ??
        m['addresses'] ??
        m['applications'];
  }
  if (raw is! List) {
    throw const ApiException(
      'The server returned an invalid list response.',
      kind: ApiErrorKind.malformed,
    );
  }
  final list = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is! Map) {
      throw const ApiException(
        'The server returned an invalid list response.',
        kind: ApiErrorKind.malformed,
      );
    }
    list.add(Map<String, dynamic>.from(e));
  }
  return list;
}

class MarketplaceRepository {
  MarketplaceRepository(this.api);
  final ApiClient api;

  Future<List<Map<String, dynamic>>> categories() async => mapList(
    envelopeData(await api.request('GET', '/categories', public: true)),
  );

  Future<List<Map<String, dynamic>>> brands() async =>
      mapList(envelopeData(await api.request('GET', '/brands', public: true)));

  Future<List<Map<String, dynamic>>> products({
    String? q,
    int? categoryId,
  }) async {
    final query = <String, dynamic>{
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'category_id': ?categoryId,
    };
    return mapList(
      envelopeData(
        await api.request('GET', '/products', public: true, query: query),
      ),
    );
  }

  Future<Map<String, dynamic>> product(int id) async => _single(
    envelopeData(await api.request('GET', '/products/$id', public: true)),
    'product',
  );

  Future<Map<String, dynamic>> me() async {
    final value = envelopeData(await api.request('GET', '/me'));
    return _single(value, 'user');
  }

  Future<Map<String, dynamic>?> resellerApplication() async {
    final value = envelopeData(
      await api.request('GET', '/reseller/application'),
    );
    if (value == null || value == false) return null;
    try {
      return _single(value, 'application');
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async =>
      _auth(
        await api.request(
          'POST',
          '/auth/login',
          public: true,
          data: {'email': email, 'password': password},
        ),
      );

  Future<Map<String, dynamic>> register(Map<String, dynamic> fields) async =>
      _auth(
        await api.request('POST', '/auth/register', public: true, data: fields),
      );

  Future<void> logout() async {
    final refresh = await api.tokens.refreshToken();
    try {
      if (refresh != null) {
        envelopeMap(
          (await api.request(
            'POST',
            '/auth/logout',
            data: {'refresh_token': refresh},
          )).data,
        );
      }
    } finally {
      await api.tokens.clear();
    }
  }

  Future<List<Map<String, dynamic>>> addresses() async =>
      mapList(envelopeData(await api.request('GET', '/addresses')));

  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> values) async =>
      _single(
        envelopeData(await api.request('POST', '/addresses', data: values)),
        'address',
      );

  Future<List<Map<String, dynamic>>> cart() async =>
      mapList(envelopeData(await api.request('GET', '/cart')));

  Future<void> addCart(Map<String, dynamic> values) async {
    envelopeMap((await api.request('POST', '/cart/items', data: values)).data);
  }

  Future<void> updateCart(int id, int quantity) async {
    envelopeMap(
      (await api.request(
        'PATCH',
        '/cart/items/$id',
        data: {'quantity': quantity},
      )).data,
    );
  }

  Future<void> removeCart(int id) async {
    envelopeMap((await api.request('DELETE', '/cart/items/$id')).data);
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> values) async =>
      _single(
        envelopeData(await api.request('POST', '/orders', data: values)),
        'order',
      );

  Future<List<Map<String, dynamic>>> orders() async =>
      mapList(envelopeData(await api.request('GET', '/orders')));

  Future<Map<String, dynamic>> order(int id) async =>
      _single(envelopeData(await api.request('GET', '/orders/$id')), 'order');

  Future<void> cancelGroup(int id) async {
    envelopeMap((await api.request('POST', '/order-groups/$id/cancel')).data);
  }

  Future<void> receivedGroup(int id) async {
    envelopeMap((await api.request('POST', '/order-groups/$id/received')).data);
  }

  Future<Map<String, dynamic>> applyReseller(
    Map<String, dynamic> values,
  ) async => _single(
    envelopeData(await api.request('POST', '/reseller/apply', data: values)),
    'application',
  );

  Future<List<Map<String, dynamic>>> resellerProducts() async =>
      mapList(envelopeData(await api.request('GET', '/reseller/products')));

  Future<Map<String, dynamic>> createResellerProduct(
    Map<String, dynamic> values,
  ) async => _single(
    envelopeData(await api.request('POST', '/reseller/products', data: values)),
    'product',
  );

  Future<void> updateResellerProduct(
    int id,
    Map<String, dynamic> values,
  ) async => envelopeMap(
    (await api.request('PUT', '/reseller/products/$id', data: values)).data,
  );

  Future<Map<String, dynamic>> deleteResellerProduct(int id) async =>
      envelopeMap((await api.request('DELETE', '/reseller/products/$id')).data);

  Future<List<Map<String, dynamic>>> resellerOrders() async =>
      mapList(envelopeData(await api.request('GET', '/reseller/orders')));

  Future<void> updateResellerGroup(int id, Map<String, dynamic> values) async {
    envelopeMap(
      (await api.request(
        'PATCH',
        '/reseller/order-groups/$id',
        data: values,
      )).data,
    );
  }

  Future<List<Map<String, dynamic>>> applications() async => mapList(
    envelopeData(await api.request('GET', '/admin/reseller-applications')),
  );

  Future<void> decideApplication(int id, String status, String? reason) async {
    envelopeMap(
      (await api.request(
        'PATCH',
        '/admin/reseller-applications/$id',
        data: {
          'status': status,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      )).data,
    );
  }

  Future<Map<String, dynamic>> createOfficialProduct(
    Map<String, dynamic> values,
  ) async => _single(
    envelopeData(await api.request('POST', '/admin/products', data: values)),
    'product',
  );

  Future<List<Map<String, dynamic>>> adminProducts() async =>
      mapList(envelopeData(await api.request('GET', '/admin/products')));

  Future<void> updateOfficialProduct(
    int id,
    Map<String, dynamic> values,
  ) async => envelopeMap(
    (await api.request('PUT', '/admin/products/$id', data: values)).data,
  );

  Future<Map<String, dynamic>> deleteOfficialProduct(int id) async =>
      envelopeMap((await api.request('DELETE', '/admin/products/$id')).data);

  Future<List<Map<String, dynamic>>> adminOrders() async =>
      mapList(envelopeData(await api.request('GET', '/admin/orders')));

  Future<void> uploadImage(File file, int productId, int sortOrder) async {
    final filename = file.uri.pathSegments.isEmpty
        ? 'product-image'
        : file.uri.pathSegments.last;
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(file.path, filename: filename),
      'product_id': productId,
      'sort_order': sortOrder,
    });
    envelopeMap(
      (await api.request('POST', '/upload/product-image', data: form)).data,
    );
  }

  Map<String, dynamic> _auth(Response<dynamic> response) {
    final map = envelopeMap(response.data);
    final tokens = _single(
      map['tokens'] ?? map['data']?['tokens'] ?? map['data'],
      'tokens',
    );
    final access = tokens['access_token'] ?? tokens['accessToken'];
    final refresh = tokens['refresh_token'] ?? tokens['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const ApiException(
        'The server returned an invalid sign-in response.',
        kind: ApiErrorKind.malformed,
      );
    }
    return {
      'access_token': access,
      'refresh_token': refresh,
      'user': _single(map['user'] ?? map['data']?['user'] ?? const {}, 'user'),
    };
  }

  Map<String, dynamic> _single(dynamic value, String named) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final nested = map[named];
      return nested is Map ? Map<String, dynamic>.from(nested) : map;
    }
    throw ApiException(
      'The server returned an invalid $named response.',
      kind: ApiErrorKind.malformed,
    );
  }
}
