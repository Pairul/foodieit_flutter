# Team module map

| Owner/module | Required actions | Screens | Store operations |
|---|---|---|---|
| Aiman — Accounts | Customer register; admin monitor; profile/address edit; deactivate | Auth, Accounts, Profile | register, login, editProfile, deactivateSelf, adminSetActive |
| Aiman — Orders | Place/retrieve; edit; delete draft; cancel/update status | Menu, Checkout, Orders | saveOrder, order/orders, deleteDraft, cancelOrder |
| Mikhail — Restaurants | Add/retrieve/list; edit details/hours; deactivate | Restaurants | saveRestaurant, restaurant/restaurants, setRestaurantActive |
| Mikhail — Menu | Add/retrieve/view; edit price/availability; remove | Menu | saveFood, food/foods, setFoodAvailable, removeFood |
| Roshan — Riders/Delivery | Rider registration/retrieval/list; delivery updates; deactivate | Auth, Rider directory, Orders, Profile | register, adminRegisterRider, users/user, assignRider, deliveryStatus, adminSetActive |
| Roshan — Reviews/Ratings | Submit/retrieve; edit; delete; ratings summary | Orders, Reviews | saveReview, reviewFor/reviews, deleteReview, average |

## Mock relationships

User(customer) → Order → Restaurant; Order → OrderLine → FoodItem; Order → User(rider); Review → delivered Order + Customer + Restaurant.

Roles are seeded or selected during customer/rider registration. No restaurant-owner role is modeled: restaurant/menu management is performed by the admin. Each user logs in with the same shared app store, which lets a team demonstrate the end-to-end workflow by switching roles on a single emulator.

The state lists and mutable entities are local presentation models, not a security boundary. UI filtering and repository mutation checks demonstrate intended permissions. Never expose the entire repository to an untrusted client in a real backend implementation.
