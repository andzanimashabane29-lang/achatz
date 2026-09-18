# Proguard rules for A-Chatz
# Disables warnings for missing Stripe push provisioning classes which are not used in the app.

-dontwarn com.stripe.android.pushProvisioning.**
