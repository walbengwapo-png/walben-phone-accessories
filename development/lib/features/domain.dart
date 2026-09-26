import '../core/network/normalizers.dart';

/// Typed, normalized models for the P1 client. SQL/JSON values are normalized
/// defensively here so the rest of the app never deals with raw types.

class Category {
  const Category({required this.id, required this.name});
  final int id;
  final String name;
  factory Category.fromJson(Map<String, dynamic> m) => Category(
    id: normInt(m['id'] ?? m['category_id']) ?? 0,
    name: normStr(m['name']),
  );
}

class Brand {
  const Brand({required this.id, required this.name});
  final int id;
  final String name;
  factory Brand.fromJson(Map<String, dynamic> m) => Brand(
    id: normInt(m['id'] ?? m['brand_id']) ?? 0,
    name: normStr(m['name']),
  );
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    required this.sortOrder,
  });
  final int id;
  final String url;
  final int sortOrder;
  factory ProductImage.fromJson(Map<String, dynamic> m) => ProductImage(
    id: normInt(m['id']) ?? 0,
    url: normStr(m['url'] ?? m['image_url'] ?? m['path']),
    sortOrder: normInt(m['sort_order'] ?? m['position'] ?? m['id']) ?? 0,
  );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.name,
    required this.stock,
  });
  final int id;
  final String name;
  final int stock;
  factory ProductVariant.fromJson(Map<String, dynamic> m) => ProductVariant(
    id: normInt(m['id']) ?? 0,
    name: normStr(m['name'] ?? m['variant_name']),
    stock: normInt(m['stock'] ?? m['stock_quantity']) ?? 0,
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.condition,
    this.sellerId,
    this.brandId,
    this.categoryId,
    this.imageUrl,
    this.sellerName,
    required this.description,
    this.status = '',
    this.images = const [],
    this.variants = const [],
  });

  final int id;
  final String name;
  final num price;
  final int stock;
  final String condition;
  final int? sellerId;
  final int? brandId;
  final int? categoryId;
  final String? imageUrl;
  final String? sellerName;
  final String description;
  final String status;
  final List<ProductImage> images;
  final List<ProductVariant> variants;

  bool get isOfficial => sellerId == null;
  bool get inStock => stock > 0;

  List<String> get imageUrls {
    if (images.isNotEmpty) {
      final sorted = [...images]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return sorted.map((e) => e.url).toList();
    }
    if ((imageUrl != null) && imageUrl!.isNotEmpty) return [imageUrl!];
    return const [];
  }

  factory Product.fromJson(Map<String, dynamic> m) {
    final rawImages = m['images'];
    final images = rawImages is List
        ? rawImages
              .whereType<Map>()
              .map((e) => ProductImage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ProductImage>[];
    final rawVariants = m['variants'] ?? m['product_variants'] ?? m['options'];
    final variants = rawVariants is List
        ? rawVariants
              .whereType<Map>()
              .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ProductVariant>[];
    return Product(
      id: normInt(m['id'] ?? m['product_id']) ?? 0,
      name: normStr(m['name']),
      price: normNum(m['price'] ?? m['base_price']),
      stock: normInt(m['stock'] ?? m['stock_quantity'] ?? m['qty']) ?? 0,
      condition: normStr(m['condition']).toLowerCase(),
      sellerId: normInt(m['seller_id']),
      brandId: normInt(m['brand_id']),
      categoryId: normInt(m['category_id']),
      imageUrl: normStrNull(
        m['image_url'] ?? m['main_image'] ?? m['primary_image'] ?? m['image'],
      ),
      sellerName: normStrNull(m['seller_name'] ?? m['store_name']),
      description: normStr(m['description']),
      status: normStr(m['status']),
      images: images,
      variants: variants,
    );
  }
}

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.stock,
    this.imageUrl,
    this.sellerId,
    this.variantName,
  });

  final int id;
  final int productId;
  final String name;
  final num unitPrice;
  final int quantity;
  final int stock;
  final String? imageUrl;
  final int? sellerId;
  final String? variantName;

  num get lineTotal => unitPrice * quantity;
  bool get isOfficial => sellerId == null;
  num get availableQuantity => stock < 0 ? quantity : stock;
  bool get stockOut => stock >= 0 && quantity > stock;

  factory CartItem.fromJson(Map<String, dynamic> m) {
    final base = normNum(m['base_price']);
    final adjustment = normNum(m['price_adjustment']);
    return CartItem(
      id: normInt(m['id'] ?? m['cart_item_id']) ?? 0,
      productId: normInt(m['product_id']) ?? 0,
      name: normStr(m['name'] ?? m['product_name']),
      unitPrice: normNum(m['price_snapshot'] ?? (base + adjustment)),
      quantity: normInt(m['quantity'] ?? m['qty']) ?? 1,
      stock:
          normInt(
            m['variant_stock'] ??
                m['stock_quantity'] ??
                m['available_stock'] ??
                m['stock'],
          ) ??
          0,
      imageUrl: normStrNull(
        m['image_url'] ?? m['main_image'] ?? m['primary_image'],
      ),
      sellerId: normInt(m['seller_id']),
      variantName: normStrNull(m['variant_name'] ?? m['option_name']),
    );
  }
}

class Cart {
  const Cart({required this.items, required this.subtotal});
  final List<CartItem> items;
  final num subtotal;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory Cart.fromItems(List<Map<String, dynamic>> rows) {
    final items = rows.map(CartItem.fromJson).toList();
    final subtotal = items.fold<num>(0, (sum, item) => sum + item.lineTotal);
    return Cart(items: items, subtotal: subtotal);
  }

  factory Cart.fromJson(dynamic value) {
    if (value is List) {
      return Cart.fromItems(value.cast<Map<String, dynamic>>().toList());
    }
    final m = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final raw = m['items'] ?? m['lines'] ?? <dynamic>[];
    final rows = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    return Cart.fromItems(rows);
  }
}

class Address {
  const Address({
    required this.id,
    required this.recipientName,
    required this.phoneNumber,
    required this.street,
    this.barangay,
    this.zipCode,
    required this.city,
    required this.province,
    required this.isDefault,
  });
  final int id;
  final String recipientName;
  final String phoneNumber;
  final String street;
  final String? barangay;
  final String? zipCode;
  final String city;
  final String province;
  final bool isDefault;

  String get oneLine => [
    street,
    barangay,
    city,
    province,
  ].where((e) => e != null && e.isNotEmpty).join(', ');
  String get label => [
    recipientName,
    phoneNumber,
    oneLine,
  ].where((e) => e.isNotEmpty).join(' - ');

  factory Address.fromJson(Map<String, dynamic> m) => Address(
    id: normInt(m['id'] ?? m['address_id']) ?? 0,
    recipientName: normStr(m['recipient_name'] ?? m['full_name'] ?? m['name']),
    phoneNumber: normStr(m['phone_number'] ?? m['phone']),
    street: normStr(m['street'] ?? m['address_line']),
    barangay: normStrNull(m['barangay']),
    zipCode: normStrNull(m['zip_code'] ?? m['postal_code']),
    city: normStr(m['city']),
    province: normStr(m['province'] ?? m['state']),
    isDefault: normBool(m['is_default'] ?? m['default']),
  );
}

class OrderGroup {
  const OrderGroup({
    required this.id,
    required this.sellerId,
    required this.status,
    this.trackingNumber,
    this.reason,
    this.storeName,
  });
  final int id;
  final int? sellerId;
  final String status;
  final String? trackingNumber;
  final String? reason;
  final String? storeName;

  bool get isOfficial => sellerId == null;
  bool get isPending => status == 'pending';
  bool get isReceivedReady => shipped || status == 'ready_for_meetup';
  bool get shipped => status == 'shipped';
  String get displaySeller => isOfficial
      ? 'Official Store'
      : (storeName != null && storeName!.isNotEmpty
            ? storeName!
            : 'Reseller order');

  factory OrderGroup.fromJson(Map<String, dynamic> m) => OrderGroup(
    id: normInt(m['id'] ?? m['order_group_id'] ?? m['group_id']) ?? 0,
    sellerId: normInt(m['seller_id']),
    status: normStr(
      m['fulfillment_status'] ?? m['status'] ?? m['group_status'],
    ),
    trackingNumber: normStrNull(m['tracking_number']),
    reason: normStrNull(m['reason'] ?? m['cancel_reason']),
    storeName: normStrNull(m['store_name']),
  );
}

class BuyerOrder {
  const BuyerOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    this.status,
    this.paymentMethod,
    this.paymentStatus,
    this.totalAmount,
    this.notes,
    this.addressId,
    this.groups = const [],
  });
  final int id;
  final String orderNumber;
  final DateTime? createdAt;
  final String? status;
  final String? paymentMethod;
  final String? paymentStatus;
  final num? totalAmount;
  final String? notes;
  final int? addressId;
  final List<OrderGroup> groups;

  bool get wasDelivery => addressId != null;

  factory BuyerOrder.fromJson(Map<String, dynamic> m) {
    final rawGroups = m['order_groups'] ?? m['groups'] ?? <dynamic>[];
    final groups = rawGroups is List
        ? rawGroups
              .whereType<Map>()
              .map((e) => OrderGroup.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <OrderGroup>[];
    return BuyerOrder(
      id: normInt(m['id'] ?? m['order_id']) ?? 0,
      orderNumber: normStr(m['order_number'] ?? m['order_no'] ?? '#${m['id']}'),
      createdAt: DateTime.tryParse(normStr(m['created_at'] ?? m['createdAt'])),
      status: normStrNull(m['status']),
      paymentMethod: normStrNull(m['payment_method']),
      paymentStatus: normStrNull(m['payment_status']),
      totalAmount: m['total_amount'] == null
          ? null
          : normNum(m['total_amount']),
      notes: normStrNull(m['notes']),
      addressId: normInt(m['address_id']),
      groups: groups,
    );
  }
}

class ResellerApplication {
  const ResellerApplication({
    required this.id,
    required this.status,
    this.storeName,
    this.storeDescription,
    this.contactNumber,
    this.documentUrl,
    this.rejectionReason,
    this.applicantName,
    this.applicantEmail,
    this.applicantPhone,
  });
  final int id;
  final String status;
  final String? storeName;
  final String? storeDescription;
  final String? contactNumber;
  final String? documentUrl;
  final String? rejectionReason;
  final String? applicantName;
  final String? applicantEmail;
  final String? applicantPhone;

  factory ResellerApplication.fromJson(Map<String, dynamic> m) =>
      ResellerApplication(
        id: normInt(m['id']) ?? 0,
        status: normStr(m['status']).toLowerCase(),
        storeName: normStrNull(m['store_name']),
        storeDescription: normStrNull(m['store_description']),
        contactNumber: normStrNull(m['contact_number']),
        documentUrl: normStrNull(m['document_url']),
        rejectionReason: normStrNull(m['reason'] ?? m['rejection_reason']),
        applicantName: normStrNull(m['full_name'] ?? m['name']),
        applicantEmail: normStrNull(m['email']),
        applicantPhone: normStrNull(m['phone_number'] ?? m['phone']),
      );
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    this.buyerName,
    this.buyerEmail,
    this.totalAmount,
    this.paymentStatus,
    this.paymentMethod,
    this.notes,
  });
  final int id;
  final String orderNumber;
  final DateTime? createdAt;
  final String? buyerName;
  final String? buyerEmail;
  final num? totalAmount;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? notes;

  factory AdminOrder.fromJson(Map<String, dynamic> m) {
    final buyer = m['buyer'] is Map
        ? Map<String, dynamic>.from(m['buyer'] as Map)
        : <String, dynamic>{};
    return AdminOrder(
      id: normInt(m['id'] ?? m['order_id']) ?? 0,
      orderNumber: normStr(m['order_number'] ?? m['order_no'] ?? '#${m['id']}'),
      createdAt: DateTime.tryParse(normStr(m['created_at'] ?? m['createdAt'])),
      buyerName: normStrNull(
        m['buyer_name'] ?? buyer['full_name'] ?? buyer['name'],
      ),
      buyerEmail: normStrNull(m['buyer_email'] ?? buyer['email']),
      totalAmount: m['total_amount'] == null
          ? null
          : normNum(m['total_amount']),
      paymentStatus: normStrNull(m['payment_status']),
      paymentMethod: normStrNull(m['payment_method']),
      notes: normStrNull(m['notes']),
    );
  }
}
