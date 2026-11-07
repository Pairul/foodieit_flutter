import 'package:flutter_test/flutter_test.dart';
import 'package:foodieit/models/entities.dart';
import 'package:foodieit/services/app_store.dart';
void main() {
  late AppStore s;
  setUp(() => s = AppStore());
  tearDown(() => s.dispose());
  void customer() => s.login('customer@example.com', 'Customer123!');
  void admin() => s.login('admin 123', 'admin@example');
  FoodOrder create({bool draft = false}) => s.saveOrder(restaurantId: 'r1', quantities: {'f1': 2, 'f2': 1}, address: 'Kajang', draft: draft);
  test('requested admin username and password are accepted', () {
    admin(); expect(s.current!.role, Role.admin);
    s.logout(); expect(() => s.login('admin 123', 'wrong'), throwsStateError);
  });
  test('customer cannot register admin or mutate catalogue', () {
    expect(() => s.register(role: Role.admin, name: 'Fake', email: 'fake@example.com', password: 'Password123', phone: '+60123456789'), throwsStateError);
    customer(); expect(() => s.removeFood('f1'), throwsStateError);
    expect(() => s.adminSetActive('rider', false), throwsStateError);
  });
  test('registration and profile editing persist across logout', () {
    s.register(role: Role.customer, name: 'New customer', email: 'NEW@example.com', password: 'Password123', phone: '+60123456789');
    s.editProfile('Changed', '+60199999999', 'Setapak'); s.logout(); s.login('new@example.com', 'Password123');
    expect(s.current!.name, 'Changed'); expect(s.current!.address, 'Setapak');
  });
  test('admin can manage restaurants, menu and riders without changing session', () {
    admin(); s.saveRestaurant(name: 'New Cafe', cuisine: 'Cafe', address: 'KL', hours: '09:00-21:00');
    final r = s.restaurants.last;
    s.saveRestaurant(id: r.id, name: 'Edited Cafe', cuisine: 'Cafe', address: 'KL', hours: '10:00-22:00');
    s.saveFood(restaurantId: r.id, name: 'Toast', description: '', price: '4.50');
    final f = s.foods.last; s.saveFood(id: f.id, restaurantId: r.id, name: 'Toast set', description: 'Fresh', price: '6.90');
    expect(f.priceCents, 690); s.setFoodAvailable(f.id, false); expect(f.available, false);
    s.removeFood(f.id); expect(f.removed, true); s.setRestaurantActive(r.id, false); expect(r.active, false);
    s.adminRegisterRider(name: 'New Rider', email: 'newrider@example.com', phone: '+60123456789', password: 'RiderPass123');
    expect(s.current!.role, Role.admin); expect(s.users.last.role, Role.rider);
  });
  test('checkout uses trusted prices, edits active order, rejects stale version', () {
    customer(); final o = create(); expect(o.totalCents, 2930);
    s.saveOrder(id: o.id, revision: 1, restaurantId: 'r1', quantities: {'f1': 1}, address: 'New address');
    expect(o.status, OrderStatus.updated); expect(o.totalCents, 1290);
    expect(() => s.saveOrder(id: o.id, revision: 1, restaurantId: 'r1', quantities: {'f1': 1}, address: 'Stale'), throwsStateError);
    s.cancelOrder(o.id); expect(o.status, OrderStatus.cancelled);
    expect(() => s.saveOrder(id: o.id, revision: o.revision, restaurantId: 'r1', quantities: {'f1': 1}, address: 'Try reopen'), throwsStateError);
  });
  test('only own draft can be deleted', () {
    customer(); final draft = create(draft: true); s.deleteDraft(draft.id);
    expect(s.orders.any((o) => o.id == draft.id), false);
    final placed = create(); expect(() => s.deleteDraft(placed.id), throwsStateError);
  });
  test('rejects mixed restaurants, unavailable items and inactive restaurants', () {
    customer(); expect(() => s.saveOrder(restaurantId: 'r1', quantities: {'f3': 1}, address: 'KL'), throwsStateError);
    admin(); s.setFoodAvailable('f1', false); customer(); expect(create, throwsStateError);
    admin(); s.setFoodAvailable('f1', true); s.setRestaurantActive('r1', false); customer(); expect(create, throwsStateError);
  });
  test('owner isolation, rider acceptance, delivery transitions and reviews', () {
    customer(); final o = create();
    s.register(role: Role.customer, name: 'Other', email: 'other@example.com', password: 'Password123', phone: '+60123456789');
    expect(() => s.cancelOrder(o.id), throwsStateError);
    expect(() => s.deleteDraft(o.id), throwsStateError);
    customer(); expect(() => s.saveReview(o.id, 5, 'Too soon'), throwsStateError);
    s.login('rider@example.com', 'Rider123!'); s.assignRider(o.id, 'rider');
    expect(() => s.deliveryStatus(o.id, OrderStatus.delivered), throwsStateError);
    expect(() => s.deactivateSelf('Rider123!'), throwsStateError);
    s.deliveryStatus(o.id, OrderStatus.pickedUp); s.deliveryStatus(o.id, OrderStatus.delivered);
    customer(); s.saveReview(o.id, 4, 'Good food'); expect(s.reviewFor(o.id)!.rating, 4);
    s.saveReview(o.id, 3, 'Edited review'); expect(s.reviews.where((r) => r.orderId == o.id).length, 1);
    expect(s.average('r1'), 4); // seeded 5 + edited 3
    s.deleteReview(s.reviewFor(o.id)!.id); expect(s.reviewFor(o.id), null);
  });
  test('deactivation rejects active orders and blocks later login', () {
    customer(); final o = create(); expect(() => s.deactivateSelf('Customer123!'), throwsStateError);
    s.cancelOrder(o.id); s.deactivateSelf('Customer123!'); expect(s.current, null);
    expect(() => s.login('customer@example.com', 'Customer123!'), throwsStateError);
  });
  test('prices use integer cents and strict input', () {
    expect(AppStore.parsePrice('12.90'), 1290); expect(AppStore.parsePrice('0.01'), 1);
    expect(() => AppStore.parsePrice('0'), throwsStateError);
    expect(() => AppStore.parsePrice('1.999'), throwsStateError);
  });
}
