/*
 
 configuration_utils.m
 TrustKit
 
 Copyright 2017 The TrustKit Project Authors
 Licensed under the MIT license, see associated LICENSE file for terms.
 See AUTHORS file for the list of project authors.
 
 */

/* For parsing IP addresses */
#import <arpa/inet.h>

#import "configuration_utils.h"
#import "TSKTrustKitConfig.h"
#import "Dependencies/domain_registry/domain_registry.h"
#import "TSKLog.h"

static NSUInteger isSubdomain(NSString *domain, NSString *subdomain)
{
    // Corner case: the supplied subdomain is actually a parent domain
    // Should never happen but https://github.com/datatheorem/TrustKit/issues/210
    if ([subdomain length] <= [domain length])
    {
        return 0;
    }

    // Ensure that the TLDs are the same; this can get tricky with TLDs like .co.uk so we take a cautious approach
    size_t domainRegistryLength = GetRegistryLength([domain UTF8String]);
    size_t subdomainRegistryLength = GetRegistryLength([subdomain UTF8String]);
    if (subdomainRegistryLength != domainRegistryLength)
    {
        return 0;
    }
    NSString *domainTld = [domain substringFromIndex: [domain length] - domainRegistryLength];
    NSString *subdomainTld = [subdomain substringFromIndex: [subdomain length] - subdomainRegistryLength];
    if (![domainTld isEqualToString:subdomainTld])
    {
        return 0;
    }
    
    // Retrieve the main domain without the TLD but append a . at the beginning
    // When initializing TrustKit, we check that [domain length] > domainRegistryLength
    NSString *domainLabel = [@"." stringByAppendingString:[domain substringToIndex:([domain length] - domainRegistryLength - 1)]];
    
    // Retrieve the subdomain's domain without the TLD
    NSString *subdomainLabel = [subdomain substringToIndex:([subdomain length] - domainRegistryLength - 1)];
    
    // Does the subdomain contain the domain
    NSArray *subComponents = [subdomainLabel componentsSeparatedByString:domainLabel];
    if ([[subComponents lastObject] isEqualToString:@""])
    {
        // This is a subdomain
        return [domainLabel length];
    }
    return 0;
}

NSString * _Nullable getPinningConfigurationKeyForDomain(NSString * _Nonnull hostname , NSDictionary<NSString *, TKSDomainPinningPolicy *> * _Nonnull domainPinningPolicies)
{
    NSString *notedHostname = nil;
    if (domainPinningPolicies[hostname] == nil)
    {
        NSUInteger bestMatch = 0;

        // No pins explicitly configured for this domain
        // Look for an includeSubdomain pin that applies
        for (NSString *pinnedServerName in domainPinningPolicies)
        {
            // Check each domain configured with the includeSubdomain flag
            if ([domainPinningPolicies[pinnedServerName][kTSKIncludeSubdomains] boolValue])
            {
                // Is the server a subdomain of this pinned server?
                TSKLog(@"Checking includeSubdomains configuration for %@", pinnedServerName);
                if ([domainPinningPolicies[pinnedServerName][kTSKForceSubdomainMatch] boolValue])
                {
                    TSKLog(@"Checking includeSubdomains by forced configuration for %@", pinnedServerName);
                    if( [hostname hasSuffix:pinnedServerName] )
                    {
                        notedHostname = pinnedServerName;
                        break;
                    }
                }
                
                NSUInteger currentMatch = isSubdomain(pinnedServerName, hostname);
                if (currentMatch > 0 && currentMatch > bestMatch)
                {
                    // Yes; let's use the parent domain's pinning configuration
                    TSKLog(@"Applying includeSubdomains configuration from %@ to %@ (new best match of %d chars)", pinnedServerName, hostname, currentMatch);
                    bestMatch = currentMatch;
                    notedHostname = pinnedServerName;
                }
                else if (currentMatch > 0)
                {
                    TSKLog(@"Not applying includeSubdomains configuration from %@ to %@ (current match of %d chars does not exceed best match)", pinnedServerName, hostname, currentMatch);
                }
            }
        }

        // Didn't find anything in the loop
        if (notedHostname == nil && domainPinningPolicies[kTSKCatchallPolicy] != nil)
        {
            if ([domainPinningPolicies[kTSKCatchallPolicy][kTSKAllowIPsOnly] boolValue]) {
                struct in6_addr addr = {};
                const char *hostnameCString = [hostname UTF8String];

                // We don't actually want to get at the address, we just want to know if it's valid or not
                if (inet_pton(AF_INET,  hostnameCString, &addr) ||
                    inet_pton(AF_INET6, hostnameCString, &addr))
                {
                    TSKLog(@"Using catchall policy (allowing IPs) for hostname %@", hostname);
                    notedHostname = kTSKCatchallPolicy;
                }
            }
            else
            {
                TSKLog(@"Using catchall policy for hostname %@", hostname);
                notedHostname = kTSKCatchallPolicy;
            }
        }
    }
    else
    {
        // This hostname has a pinnning configuration
        notedHostname = hostname;
    }
    
    if (notedHostname == nil)
    {
        TSKLog(@"Domain %@ is not pinned", hostname);
    }
    return notedHostname;
}
