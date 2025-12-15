# Keep classes for Stripe Push Provisioning
-keep class com.stripe.android.pushProvisioning.** { *; }
-keep interface com.stripe.android.pushProvisioning.** { *; }

# Keep specific Stripe Push Provisioning classes
-keep class com.stripe.android.pushProvisioning.EphemeralKeyUpdateListener { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivity$g { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider { *; }

# Additional keep rules for Stripe
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# Keep generic Parcelable classes
-keep class android.os.Parcelable { *; }
-keep class kotlinx.parcelize.** { *; }
