# Moving the simulator to a real backend

This bundle intentionally implements local mock state. It does not pretend to authenticate against Firebase or the earlier PHP project. The hardcoded admin login requested for the simulator must not be embedded as a production backdoor.

## Service boundary

Keep model/screen responsibilities but change store methods into asynchronous operations backed by an authenticated repository. Add loading/error states, server IDs, DTO serialization, pagination, caching and server streams/polling. Replace seeded credentials with actual identity-provider sessions. Widget callbacks currently call synchronous methods; they must await the new operations and disable repeated submissions while waiting. Do not simply make the methods async without updating those callbacks.

Suggested repository families: AuthRepository, AccountsRepository, RestaurantsRepository, MenuRepository, OrdersRepository, DeliveriesRepository and ReviewsRepository. AppStore then coordinates these and emits view state; the repository implementation may use Firebase or REST. A shared interface is not included here because this deliverable uses only one local implementation.

## REST/PHP option

| Mock operation | Suggested authenticated endpoint |
|---|---|
| Login/register/profile/deactivate | POST /auth/login, POST /customers, PATCH /me, POST /me/deactivate |
| Customer/rider monitoring | GET /admin/customers, GET /admin/riders |
| Restaurants | GET/POST /restaurants, PATCH /restaurants/{id}, POST /restaurants/{id}/deactivate |
| Menu CRUD | GET/POST /restaurants/{id}/foods, PATCH/DELETE /foods/{id} |
| Order CRUD | GET/POST /orders, GET/PATCH /orders/{id}, DELETE /orders/{id}/draft |
| Assignment/status | POST /orders/{id}/assignment, POST /orders/{id}/delivery-status |
| Reviews/summaries | GET/POST /reviews, PATCH/DELETE /reviews/{id}, GET /restaurants/{id}/ratings |

The previous PHP project uses cookie sessions/CSRF and different endpoints/statuses. Native Flutter integration would need deliberate cookie storage + CSRF handling or a carefully designed token API, and added restaurant/rider/review backend modules. This Flutter code is not wired to that PHP API. Do not assume shared authentication, data or status enums.

On the server enforce identity, roles, record ownership, active-account checks, legal state transitions, integer-cents pricing, item availability, one restaurant per order, review eligibility and deactivation constraints. Store order item snapshots. Use transactions/row locking, revision checks and idempotency keys for retries. Never accept a client's price/total or role as authority. Add HTTPS, secure token storage/refresh, rate limiting, audit logs and verified account recovery.

## Firebase option

Use Firebase Authentication for real customer/rider accounts. Store user profiles and domain entities in Firestore, but assign privileged roles through server-managed custom claims. A human-readable admin alias such as `admin 123` needs a deliberate server-side identity design; do not map it to a hardcoded privileged password in the app.

Use restrictive Firestore rules for ownership and role access. Use trusted Cloud Functions/Cloud Run operations for order totals/transitions, rider assignment and derived review aggregates, with transactional checks and server timestamps. A mobile client must not be able to write its own admin role or authoritative totals. Firebase setup requires your own project configuration; none is included in this mock app.

Add real payment-provider integration, restaurant acceptance stages, stock rules, fees/tax, rider verification, push notifications, address validation and privacy/retention controls only when the team's scope requires them. The current hours field is display-only; opening-hours enforcement needs timezone/day schedules and overnight handling.
