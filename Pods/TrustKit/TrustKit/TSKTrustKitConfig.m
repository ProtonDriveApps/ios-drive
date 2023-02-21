/*

 TSKTrustKitConfig.m
 TrustKit
 
 Copyright 2017 The TrustKit Project Authors
 Licensed under the MIT license, see associated LICENSE file for terms.
 See AUTHORS file for the list of project authors.
 
 */

#import "TSKTrustKitConfig.h"

NSString * const TrustKitVersion = @"2.1.0";

// General keys
const TSKGlobalConfigurationKey kTSKSwizzleNetworkDelegates = @"TSKSwizzleNetworkDelegates";
const TSKGlobalConfigurationKey kTSKPinnedDomains = @"TSKPinnedDomains";

const TSKGlobalConfigurationKey kTSKIgnorePinningForUserDefinedTrustAnchors = @"TSKIgnorePinningForUserDefinedTrustAnchors";

// Keys for each domain within the TSKPinnedDomains entry
const TSKDomainConfigurationKey kTSKPublicKeyHashes = @"TSKPublicKeyHashes";
const TSKDomainConfigurationKey kTSKEnforcePinning = @"TSKEnforcePinning";
const TSKDomainConfigurationKey kTSKExcludeSubdomainFromParentPolicy = @"kSKExcludeSubdomainFromParentPolicy";

const TSKDomainConfigurationKey kTSKIncludeSubdomains = @"TSKIncludeSubdomains";
const TSKDomainConfigurationKey kTSKForceSubdomainMatch = @"TSKForceSubdomainMatch";
const TSKDomainConfigurationKey kTSKNoSSLValidation = @"TSKNoSSLValidation";
const TSKDomainConfigurationKey kTSKPublicKeyAlgorithms = @"TSKPublicKeyAlgorithms";
const TSKDomainConfigurationKey kTSKReportUris = @"TSKReportUris";
const TSKDomainConfigurationKey kTSKDisableDefaultReportUri = @"TSKDisableDefaultReportUri";
const TSKDomainConfigurationKey kTSKExpirationDate = @"TSKExpirationDate";
const TSKDomainConfigurationKey kTSKCatchallPolicy = @"TSKCatchallPolicy";
const TSKDomainConfigurationKey kTSKNoHostnameValidation = @"TSKNoHostnameValidation";
const TSKDomainConfigurationKey kTSKAllowIPsOnly = @"TSKAllowIPsOnly";

// Keep this around to prevent build errors
const TSKDomainConfigurationKey kForceSubdomains = kTSKNoSSLValidation;

#pragma mark Public key Algorithms Constants
const TSKSupportedAlgorithm kTSKAlgorithmRsa2048 = @"TSKAlgorithmRsa2048";
const TSKSupportedAlgorithm kTSKAlgorithmRsa4096 = @"TSKAlgorithmRsa4096";
const TSKSupportedAlgorithm kTSKAlgorithmEcDsaSecp256r1 = @"TSKAlgorithmEcDsaSecp256r1";
const TSKSupportedAlgorithm kTSKAlgorithmEcDsaSecp384r1 = @"TSKAlgorithmEcDsaSecp384r1";
