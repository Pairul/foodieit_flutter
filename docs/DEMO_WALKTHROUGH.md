# One-emulator demonstration

Keep the same app process running throughout. Sign out using Profile; do not restart the app while changing roles.

1. **Admin / Mikhail:** Log in with `admin 123` / `admin@example`. Open Stores. Add a restaurant with name, cuisine, address and `09:00-22:00`. Edit its hours. Open Manage menu, add a food with price `12.90`, edit the price, toggle availability, and remove an extra food. Keep at least one available item and the restaurant active.
2. **Admin / Roshan:** Delivery → Rider directory. Register a rider with email, phone and a password. View the new rider. Deactivate/reactivate that rider before assigning an order. The admin session remains selected.
3. **Customer / Aiman:** Profile → Sign out. Use Create customer account, fill the form and save. Discover → restaurant → choose quantities → Review cart. Enter an address and Save draft. Back on Discover, use Orders to retrieve the draft, edit quantities/address, and place it. Create another draft and delete it. Create an extra order and cancel it to demonstrate cancellation.
4. **Customer / Aiman:** Edit the active placed order; verify Updated and its revised total. Open Profile and edit the default address. Order addresses remain independent snapshots.
5. **Admin / Aiman:** Sign out, log in as admin, view the new account in Accounts and search it. Delivery → Deliveries retrieves all orders. Assign the active customer order to the seeded rider Roshan (or your new rider).
6. **Rider / Roshan:** Sign out, log in using `rider@example.com` / `Rider123!` (or the new rider's credentials). Deliveries shows assigned jobs; use Mark picked up, then Mark delivered. Alternatively leave an order unassigned and use Accept delivery in the rider login.
7. **Customer / Roshan:** Sign back into the order owner's account. Orders now shows Delivered. Write a review, edit its stars/comment, then view Reviews and its restaurant average. Delete the review, then submit it again from the delivered order.
8. **Customer / Aiman:** Once no active orders remain, Profile → Deactivate account. Confirm password. Try signing in again; access is denied. The admin can still monitor the inactive account and reactivate it.

For a quicker start use the seeded customer `customer@example.com` / `Customer123!`. A delivered order and 5-star review are already present, so review edit/delete is immediately demonstrable.

## Manual edge checks

- Wrong password and duplicate email show errors without closing a registration form.
- A customer cannot open admin bottom tabs; a rider cannot edit someone else's order.
- Customer orders cannot mix restaurants, accept zero/negative quantities, or place unavailable/removed food.
- A deactivated restaurant remains visible to admin but disappears from customer discovery.
- Existing historical totals remain unchanged when admin edits a menu price.
- Customers cannot edit an assigned/delivered/cancelled order or review undelivered food.
- A rider cannot skip pickup, update another rider's job, or deactivate while assigned work remains active.
- Review deletion updates count/average immediately.
- Test at small phone size and larger tablet/window width, with keyboard shown and increased system text size.
- Cold restart intentionally resets all demo changes.
