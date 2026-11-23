// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// URL Sanitizer: the one cleaning function, the site rules it reads, the
/// Site sheet's draft, search, the move from Clean URL's lists, and the copy.
enum URLSanitizerTests {
    static func run(_ suite: TestSuite) {
        func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
            suite.expect(actual == expected, "\(label): got \(actual), expected \(expected)", file: file, line: line)
        }
        func cleaned(_ link: String, _ rules: URLCleaning.Rules = .builtIn) -> String {
            URLCleaning.clean(link, rules: rules)?.url ?? "<nil>"
        }
        func rules(_ edit: (inout [URLCleaning.Site]) -> Void) -> URLCleaning.Rules {
            var sites = URLCleaning.Rules.builtIn.sites
            edit(&sites)
            return URLCleaning.Rules(sites: sites)
        }
        func index(_ id: String, _ sites: [URLCleaning.Site]) -> Int {
            sites.firstIndex { $0.id == id } ?? 0
        }
        let global = URLCleaning.globalSiteID

        // MARK: Encoding, order, fragment

        expectEqual(cleaned("https://example.com/a%20b/caf%C3%A9?q=hello%20world&utm_source=x&path=%2Fa%2Fb&emoji=%F0%9F%98%80#frag%20ment"),
                    "https://example.com/a%20b/caf%C3%A9?q=hello%20world&path=%2Fa%2Fb&emoji=%F0%9F%98%80#frag%20ment",
                    "kept parameters, the path and the fragment keep their original encoding")
        expectEqual(cleaned("https://example.com/?b=2&utm_medium=m&a=1&c=3"), "https://example.com/?b=2&a=1&c=3",
                    "kept parameters stay in their original order, never sorted")
        expectEqual(cleaned("https://example.com/p?q=a+b&utm_source=x"), "https://example.com/p?q=a+b",
                    "a plus sign in a kept value is not rewritten as a space")
        expectEqual(cleaned("https://example.com/p?utm_source=x&fbclid=y#top"), "https://example.com/p#top",
                    "the question mark goes when nothing is left, the fragment stays")
        expectEqual(cleaned("https://example.com/p?a=1&&utm_source=x&b"), "https://example.com/p?a=1&&b",
                    "empty pairs and bare flags that are not trackers stay as written")
        expectEqual(cleaned("https://example.com/?q=日本&utm_source=x"), "https://example.com/?q=日本",
                    "literal Unicode in a kept value is not percent-encoded")
        suite.expect(URLCleaning.clean("ftp://example.com/?utm_source=x") == nil
                        && URLCleaning.clean("mailto:a@example.com?utm_source=x") == nil
                        && URLCleaning.clean("example.com/?utm_source=x") == nil,
                     "only http and https links are processed")

        // MARK: Duplicates

        let duplicate = URLCleaning.clean("https://example.com/?utm_source=a&id=1&UTM_SOURCE=b&id=2&fbclid=c")
        expectEqual(duplicate?.url ?? "", "https://example.com/?id=1&id=2",
                    "every copy of a duplicated parameter is judged on its own")
        expectEqual(duplicate?.removed ?? [], ["utm_source", "fbclid"],
                    "a duplicated tracker is named once, in the case first seen")
        expectEqual(duplicate?.kept ?? [], ["id"], "a duplicated kept parameter is named once")

        // MARK: Wildcards

        let wildcard = rules { sites in
            sites[0].tokens.append(URLCleaning.Token(name: "ref_*", isCustom: true))
        }
        expectEqual(cleaned("https://example.com/?ref_a=1&REF_B=2&reference=3&ref=4", wildcard),
                    "https://example.com/?reference=3&ref=4",
                    "a token ending in * removes every parameter starting with its prefix, any case")
        expectEqual(URLCleaning.clean("https://example.com/?ref_a=1", rules: wildcard)?.removals.first?.token ?? "",
                    "ref_*", "a removal names the wildcard token that matched")
        expectEqual(cleaned("https://example.com/?utm_anything=1&id=2"), "https://example.com/?id=2",
                    "the built-in utm_* wildcard covers names the old list never listed")
        let utmAllowed = rules { sites in
            sites[0].tokens = sites[0].tokens.map { var token = $0; token.isBlocked = $0.name != "utm_*"; return token }
        }
        expectEqual(cleaned("https://example.com/?utm_source=a&fbclid=b", utmAllowed),
                    "https://example.com/?utm_source=a", "an allowed wildcard leaves its whole family in")

        // MARK: Site vs All sites

        let mixed = URLCleaning.clean("https://www.youtube.com/watch?v=1&si=x&utm_source=y&t=42")
        expectEqual(mixed?.url ?? "", "https://www.youtube.com/watch?v=1&t=42", "site and global tokens both clean")
        expectEqual(mixed?.removals.map(\.siteID) ?? [], ["youtube", global],
                    "each removal is credited to the site whose token removed it")
        expectEqual(mixed?.kept ?? [], ["v", "t"], "kept names are listed for the result line")
        expectEqual(cleaned("https://example.com/?si=keep&t=keep&s=keep"), "https://example.com/?si=keep&t=keep&s=keep",
                    "a site's tokens never reach another site")
        let youtubeOff = rules { sites in sites[index("youtube", sites)].isOn = false }
        expectEqual(cleaned("https://youtu.be/abc?si=x&utm_source=y", youtubeOff), "https://youtu.be/abc?si=x",
                    "a site switched off leaves its tokens while All sites still cleans")
        let globalOff = rules { sites in sites[0].isOn = false }
        expectEqual(cleaned("https://youtu.be/abc?si=x&utm_source=y", globalOff), "https://youtu.be/abc?utm_source=y",
                    "All sites switched off leaves global trackers while a site still cleans")
        let fbclidAllowedOnX = rules { sites in
            sites[index("x", sites)].tokens.append(URLCleaning.Token(name: "fbclid", isBlocked: false, isCustom: true))
        }
        expectEqual(cleaned("https://x.com/a?fbclid=1&utm_medium=x", fbclidAllowedOnX), "https://x.com/a?fbclid=1",
                    "a token the site allows stays though All sites blocks it, and what the site does not list still goes")
        expectEqual(cleaned("https://example.com/a?fbclid=1", fbclidAllowedOnX), "https://example.com/a",
                    "a site's allowed token only keeps it on that site's links")
        let utmSourceAllowedOnYouTube = rules { sites in
            sites[index("youtube", sites)].tokens += [URLCleaning.Token(name: "utm_*", isCustom: true),
                                                     URLCleaning.Token(name: "utm_source", isBlocked: false, isCustom: true)]
        }
        expectEqual(cleaned("https://www.youtube.com/watch?v=1&si=abc&utm_source=n&utm_medium=e", utmSourceAllowedOnYouTube),
                    "https://www.youtube.com/watch?v=1&utm_source=n",
                    "an exact allowed name beats the site's blocked wildcard")
        let siteOffAllowed = rules { sites in
            let x = index("x", sites)
            sites[x].tokens.append(URLCleaning.Token(name: "fbclid", isBlocked: false, isCustom: true))
            sites[x].isOn = false
        }
        expectEqual(cleaned("https://x.com/a?fbclid=1", siteOffAllowed), "https://x.com/a",
                    "a switched-off site's allowed token no longer shields it from All sites")
        let pausedSiteToken = rules { sites in
            let youtube = index("youtube", sites)
            sites[youtube].tokens = sites[youtube].tokens.map { var token = $0; token.isBlocked = $0.name != "si"; return token }
        }
        expectEqual(cleaned("https://www.youtube.com/watch?v=1&si=x&feature=share", pausedSiteToken),
                    "https://www.youtube.com/watch?v=1&si=x", "an allowed site token stays while its siblings go")

        // MARK: Host normalization

        for (link, expected) in [
            ("https://m.youtube.com/watch?v=1&si=x", "https://m.youtube.com/watch?v=1"),
            ("https://mobile.twitter.com/a/status/1?s=20", "https://mobile.twitter.com/a/status/1"),
            ("https://open.spotify.com/track/abc?si=xyz", "https://open.spotify.com/track/abc"),
            ("https://WWW.X.com/a?t=abc", "https://WWW.X.com/a"),
            ("https://music.youtube.com/watch?v=1&si=x", "https://music.youtube.com/watch?v=1"),
        ] {
            expectEqual(cleaned(link), expected, "the host matches its site: \(link)")
        }
        expectEqual(URLCleaning.matchingHost("open.com"), "open.com",
                    "a prefix that is the whole remaining name is not stripped")
        expectEqual(URLCleaning.matchingHost("www.m.example.com"), "example.com", "stacked prefixes are all stripped")
        expectEqual(URLCleaning.matchingHost("www.open.com"), "open.com", "stripping stops at the site itself")
        expectEqual(URLCleaning.domain(from: "www.m.youtube.com") ?? "", "youtube.com",
                    "a domain normalizes to what the rules store")
        let nested = rules { sites in
            sites.append(URLCleaning.Site(id: "custom-music", name: "Music", domains: ["music.youtube.com"],
                                          tokens: [URLCleaning.Token(name: "ref", isCustom: true)]))
        }
        let nestedResult = URLCleaning.clean("https://music.youtube.com/watch?v=1&si=x&ref=y", rules: nested)
        expectEqual(nestedResult?.url ?? "", "https://music.youtube.com/watch?v=1&si=x",
                    "a site for a nested domain wins over the site for the domain around it")
        expectEqual(nested.site(forHost: "www.youtube.com")?.id ?? "", "youtube",
                    "the outer site still owns the rest of its domain")

        // MARK: Domain and token input

        for (input, expected) in [
            (" https://WWW.Example.com/path?x=1#f ", "example.com"),
            ("https://user:pass@Shop.Example.com:8080/x", "shop.example.com"),
            ("m.example.com", "example.com"),
            ("open.com", "open.com"),
            ("youtu.be", "youtu.be"),
            ("bücher.de", "bücher.de"),
            ("192.0.2.1", "192.0.2.1"),
            ("https://[2001:db8::1]:8080/x", "[2001:db8::1]"),
        ] {
            expectEqual(URLCleaning.domain(from: input) ?? "<nil>", expected, "domain from \(input)")
        }
        for invalid in ["not a domain", "example", ".example.com", "example.com.", "exa_mple.com", "a..com",
                        "-a.com", "example.com|ref", ""] {
            suite.expect(URLCleaning.domain(from: invalid) == nil, "\(invalid) is not a domain")
        }
        expectEqual(URLCleaning.tokenName(from: " Ref ") ?? "", "ref", "a token is trimmed and lowercased")
        expectEqual(URLCleaning.tokenName(from: "UTM_*") ?? "", "utm_*", "a wildcard token keeps its star")
        for invalid in ["*", "a*b", "a=b", "a&b", "a b", ""] {
            suite.expect(URLCleaning.tokenName(from: invalid) == nil, "\(invalid) is not a token")
        }
        expectEqual(URLCleaning.tokenNames(fromPasted: "ref, Source\nREF  bad=name x*"), ["ref", "source", "x*"],
                    "pasted tokens split on commas and whitespace, valid ones once each")
        let percentDomain = URLCleaning.clean("https://reddit.com/r/a/?%24deep_link=true&sort=new")
        expectEqual(percentDomain?.url ?? "", "https://reddit.com/r/a/?sort=new",
                    "a percent-encoded name is matched by its decoded spelling")

        // MARK: Rules storage and reconciliation

        let builtIn = URLCleaning.Rules.builtIn
        expectEqual(builtIn.sites.first?.id ?? "", global, "All sites leads the list")
        expectEqual(builtIn.sites.dropFirst().map(\.name),
                    ["Bilibili", "Instagram", "Reddit", "Spotify", "TikTok", "X", "Xiaohongshu", "YouTube"],
                    "built-in sites follow alphabetically")
        suite.expect(builtIn.sites.flatMap(\.tokens).allSatisfy { $0.name == $0.name.lowercased() && !$0.isCustom },
                     "built-in tokens are lowercase and not deletable")
        let allDomains = builtIn.sites.flatMap(\.domains)
        expectEqual(allDomains.count, Set(allDomains).count, "no domain belongs to two built-in sites")
        var withCustom = builtIn
        withCustom.upsert(URLCleaning.Site(id: "custom-a", name: "", domains: ["https://WWW.Weibo.com/x"],
                                           tokens: [URLCleaning.Token(name: "SudaRef", isCustom: true),
                                                    URLCleaning.Token(name: "sudaref", isCustom: true)]))
        let restored = URLCleaning.Rules(storedValue: withCustom.storageValue)
        expectEqual(restored, withCustom, "stored rules read back the same")
        expectEqual(restored.sites.last?.domains ?? [], ["weibo.com"], "stored domains are normalized")
        expectEqual(restored.sites.last?.name ?? "", "weibo.com", "a nameless site takes its first domain")
        expectEqual(restored.sites.last?.tokens.map(\.name) ?? [], ["sudaref"],
                    "duplicate tokens collapse without regard to case")
        expectEqual(cleaned("https://weibo.com/a?sudaref=x&id=1", restored), "https://weibo.com/a?id=1",
                    "a site the user added cleans its domain")
        withCustom.delete(id: "youtube")
        withCustom.delete(id: global)
        withCustom.delete(id: "custom-a")
        suite.expect(withCustom.site(id: "youtube") != nil && withCustom.site(id: global) != nil
                        && withCustom.site(id: "custom-a") == nil,
                     "only a site the user added can be deleted")

        var trimmedYouTube = builtIn.site(id: "youtube")!
        trimmedYouTube.tokens.removeAll { $0.name == "kw" }
        trimmedYouTube.tokens[0].isBlocked = false
        let upgraded = URLCleaning.Rules(sites: [trimmedYouTube])
        let upgradedYouTube = upgraded.site(id: "youtube")
        suite.expect(upgradedYouTube?.tokens.contains { $0.name == "kw" && $0.isBlocked && !$0.isCustom } == true
                        && upgradedYouTube?.tokens.first?.isBlocked == false,
                     "a built-in token a stored list lacks comes back blocked, choices kept")
        suite.expect(upgraded.site(id: global) != nil && upgraded.site(id: "x") != nil,
                     "built-in sites missing from a stored list are restored")
        let claimed = URLCleaning.Rules(sites: [URLCleaning.Site(id: "custom-z", name: "Z", domains: ["x.com"],
                                                                 tokens: [])])
        expectEqual(claimed.site(id: "x")?.domains ?? [], ["twitter.com"],
                    "a restored built-in site never takes a domain another site claimed")
        expectEqual(URLCleaning.Rules(storedValue: "not json"), builtIn, "an unreadable list reads as the built-ins")

        // MARK: Search

        let sites = builtIn.sites
        expectEqual(URLCleaning.search("", in: sites, globalName: "All sites").count, sites.count,
                    "an empty search keeps every site")
        expectEqual(URLCleaning.search("tube", in: sites, globalName: "All sites").map(\.site.id), ["youtube"],
                    "search matches site names")
        expectEqual(URLCleaning.search("YOUTU.BE", in: sites, globalName: "All sites").map(\.site.id), ["youtube"],
                    "search matches domains without regard to case")
        let tokenSearch = URLCleaning.search("fbcl", in: sites, globalName: "All sites")
        suite.expect(tokenSearch.map(\.site.id) == [global] && tokenSearch.first?.matchingTokens == ["fbclid"],
                     "a site found through its tokens names them")
        expectEqual(URLCleaning.search("tous", in: sites, globalName: "Tous les sites").map(\.site.id), [global],
                    "All sites is found by its name as shown")
        suite.expect(URLCleaning.search("zzzz", in: sites, globalName: "All sites").isEmpty, "no match, no rows")

        expectEqual(URLCleaning.Site.monogram(for: "YouTube"), "Y", "one word gives one letter")
        expectEqual(URLCleaning.Site.monogram(for: "Hacker News"), "HN", "two words give two letters")
        expectEqual(URLCleaning.Site.monogram(for: "weibo.com"), "WC", "a domain name gives its first letters")

        // MARK: Site draft

        var add = URLSanitizerSiteDraft(adding: "custom-new")
        suite.expect(!add.canSave && add.mode == .add && !add.canDelete, "a new site waits for a domain")
        add.domainInput = "news.example"
        suite.expect(add.canSave, "a domain still being typed is enough for the primary button")
        add.domainInput = "https://www.news.example/x, other.example "
        add.commitDomainInput(rules: builtIn, globalName: "All sites")
        expectEqual(add.site.domains, ["news.example", "other.example"], "several pasted domains commit at once")
        expectEqual(add.domainInput, "", "committed text leaves the field")
        add.domainInput = "youtu.be"
        add.commitDomainInput(rules: builtIn, globalName: "All sites")
        expectEqual(add.domainProblem, .claimed(domain: "youtu.be", siteName: "YouTube"),
                    "a domain another site lists is refused with that site's name")
        expectEqual(add.domainInput, "youtu.be", "a refused domain stays in the field")
        add.domainInput = "www.m.youtube.com"
        add.commitDomainInput(rules: builtIn, globalName: "All sites")
        expectEqual(add.domainProblem, .claimed(domain: "youtube.com", siteName: "YouTube"),
                    "stacked prefixes are checked against the domain the rules would store")
        add.domainInput = "not a domain"
        add.commitDomainInput(rules: builtIn, globalName: "All sites")
        expectEqual(add.domainProblem, .notADomain("not"), "text that is not a domain is refused")
        add.domainInput = ""
        add.removeLastDomain()
        expectEqual(add.site.domains, ["news.example"], "backspace in an empty field removes the last domain")
        add.tokenInput = "Ref, ref SOURCE bad=one"
        add.commitTokenInput()
        expectEqual(add.site.tokens.map(\.name), ["ref", "source"], "tokens add once each without regard to case")
        expectEqual(add.tokenInput, "bad=one", "text that is not a token stays in the field")
        expectEqual(add.rejectedToken ?? "", "bad=one", "the rejected token is named")
        var rejectedSave = add
        suite.expect(rejectedSave.finalized(rules: builtIn, globalName: "All sites") == nil
                     && rejectedSave.site.tokens.map(\.name) == ["ref", "source"],
                     "Save stays open over a rejected token and keeps the accepted ones")
        add.tokenInput = ""
        add.commitTokenInput()
        suite.expect(add.rejectedToken == nil, "an emptied token field clears the problem")
        expectEqual(add.previewMonogram, "N", "the tile previews the first domain until there is a name")
        add.toggleToken("ref")
        suite.expect(add.site.tokens.first?.isBlocked == false && add.site.allowedCount == 1,
                     "clicking a token allows it")
        add.blockAll()
        expectEqual(add.site.allowedCount, 0, "Block all blocks every token")
        add.deleteToken("source")
        expectEqual(add.site.tokens.map(\.name), ["ref"], "a custom token can be deleted")
        let added = add.finalized(rules: builtIn, globalName: "All sites")
        suite.expect(added?.name == "news.example" && added?.domains == ["news.example"],
                     "an empty name saves as the first domain")

        var empty = URLSanitizerSiteDraft(adding: "custom-empty")
        empty.domainInput = "  "
        suite.expect(empty.finalized(rules: builtIn, globalName: "All sites") == nil
                        && empty.domainProblem == .missing,
                     "saving without a domain asks for one")

        var editYouTube = URLSanitizerSiteDraft(editing: builtIn.site(id: "youtube")!)
        suite.expect(editYouTube.mode == .edit && !editYouTube.canDelete, "a built-in site cannot be deleted")
        editYouTube.deleteToken("si")
        suite.expect(editYouTube.site.tokens.contains { $0.name == "si" }, "a built-in token cannot be deleted")
        editYouTube.removeDomain("youtu.be")
        editYouTube.domainInput = "youtube-nocookie.com"
        let editedYouTube = editYouTube.finalized(rules: builtIn, globalName: "All sites")
        expectEqual(editedYouTube?.domains ?? [], ["youtube.com", "youtube-nocookie.com"],
                    "a built-in site's domains can be edited, pending text included")
        var editedRules = builtIn
        editedYouTube.map { editedRules.upsert($0) }
        expectEqual(cleaned("https://youtube-nocookie.com/embed/1?si=x", editedRules),
                    "https://youtube-nocookie.com/embed/1", "Save applies the edited domains")
        expectEqual(cleaned("https://youtu.be/1?si=x", editedRules), "https://youtu.be/1?si=x",
                    "a removed domain no longer matches the site")

        var editGlobal = URLSanitizerSiteDraft(editing: builtIn.global)
        suite.expect(editGlobal.mode == .global && editGlobal.canSave && !editGlobal.canDelete,
                     "All sites saves without domains and cannot be deleted")
        editGlobal.tokenInput = "gclid utm_*"
        editGlobal.commitTokenInput()
        expectEqual(editGlobal.site.tokens.count, builtIn.global.tokens.count, "existing tokens are not added twice")
        var customOwner = builtIn
        customOwner.upsert(URLCleaning.Site(id: "custom-o", name: "Owner", domains: ["owner.example"], tokens: []))
        var editCustom = URLSanitizerSiteDraft(editing: customOwner.site(id: "custom-o")!)
        suite.expect(editCustom.canDelete, "a site the user added can be deleted")
        editCustom.domainInput = "owner.example"
        suite.expect(editCustom.commitDomainInput(rules: customOwner, globalName: "All sites"),
                     "a site's own domain is not reported as claimed")

        // MARK: Migration

        let legacy = URLCleaning.migratedSites(
            globalNames: "Ref, keep",
            siteNames: "twitter.com|tw_only,x.com|x_only,youtu.be|yt_extra,weibo.com|sudaref,m.reddit.com|r_extra",
            disabledNames: "|utm_*,|keep,twitter.com|s,x.com|t,youtube.com|si,weibo.com|sudaref")
        let migrated = URLCleaning.Rules(sites: legacy)
        let x = migrated.site(id: "x")
        expectEqual(x?.name ?? "", "X", "twitter.com and x.com merge into X")
        expectEqual(x?.domains ?? [], ["x.com", "twitter.com"], "X keeps both domains")
        suite.expect(x?.tokens.first { $0.name == "s" }?.isBlocked == false
                        && x?.tokens.first { $0.name == "t" }?.isBlocked == false
                        && x?.tokens.first { $0.name == "cn" }?.isBlocked == true,
                     "a name unchecked on either X host stays allowed")
        suite.expect(x?.tokens.contains { $0.name == "tw_only" && $0.isCustom && $0.isBlocked } == true
                        && x?.tokens.contains { $0.name == "x_only" && $0.isCustom } == true,
                     "names added to either X host become custom tokens of X")
        let youtube = migrated.site(id: "youtube")
        suite.expect(youtube?.domains == ["youtube.com", "youtu.be"]
                        && youtube?.tokens.first { $0.name == "si" }?.isBlocked == false
                        && youtube?.tokens.contains { $0.name == "yt_extra" && $0.isCustom } == true,
                     "youtube.com and youtu.be merge into YouTube with the union of their tokens")
        let migratedGlobal = migrated.global
        suite.expect(migratedGlobal.tokens.first { $0.name == "utm_*" }?.isBlocked == false
                        && migratedGlobal.tokens.first { $0.name == "fbclid" }?.isBlocked == true
                        && migratedGlobal.tokens.contains { $0.name == "ref" && $0.isCustom && $0.isBlocked }
                        && migratedGlobal.tokens.contains { $0.name == "keep" && $0.isCustom && !$0.isBlocked },
                     "the All sites list keeps checked as blocked, unchecked as allowed, added as custom")
        let weibo = migrated.sites.first { $0.domains == ["weibo.com"] }
        suite.expect(weibo?.name == "weibo.com" && weibo?.isBuiltIn == false
                        && weibo?.tokens == [URLCleaning.Token(name: "sudaref", isBlocked: false, isCustom: true)],
                     "a host the user added becomes a custom site of its own")
        suite.expect(migrated.site(id: "reddit")?.tokens.contains { $0.name == "r_extra" && $0.isCustom } == true,
                     "a host that now normalizes to a built-in domain joins that site")
        suite.expect(migrated.sites.allSatisfy(\.isOn), "every migrated site starts on")
        expectEqual(URLCleaning.migratedSites(globalNames: "", siteNames: "", disabledNames: ""), builtIn.sites,
                    "an untouched setup migrates to the built-ins")

        let suiteName = "io.github.sam32j.lattice.tests.url-sanitizer-migration"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(true, forKey: DefaultsKey.urlCleanerEnabled)
            defaults.set("youtube.com|extra", forKey: DefaultsKey.urlCleanerSiteParameters)
            defaults.set("x.com|t", forKey: DefaultsKey.urlCleanerDisabledParameters)
            Defaults.migrateURLCleanerRules(in: defaults)
            let stored = URLCleaning.Rules(storedValue: defaults.string(forKey: DefaultsKey.urlSanitizerSites))
            suite.expect(stored.site(id: "youtube")?.tokens.contains { $0.name == "extra" } == true
                            && stored.site(id: "x")?.tokens.first { $0.name == "t" }?.isBlocked == false,
                         "the migration stores the old lists as sites")
            suite.expect(defaults.bool(forKey: DefaultsKey.urlCleanerEnabled),
                         "the migration keeps the main switch as it was")
            suite.expect([DefaultsKey.urlCleanerCustomParameters, DefaultsKey.urlCleanerSiteParameters,
                          DefaultsKey.urlCleanerDisabledParameters].allSatisfy { defaults.object(forKey: $0) == nil },
                         "the old lists are removed after the move")
            let afterFirst = defaults.string(forKey: DefaultsKey.urlSanitizerSites)
            defaults.set("youtube.com|later", forKey: DefaultsKey.urlCleanerSiteParameters)
            Defaults.migrateURLCleanerRules(in: defaults)
            expectEqual(defaults.string(forKey: DefaultsKey.urlSanitizerSites) ?? "", afterFirst ?? "",
                        "the migration runs once and never overwrites stored sites")
            defaults.removePersistentDomain(forName: suiteName)
            Defaults.migrateURLCleanerRules(in: defaults)
            suite.expect(defaults.object(forKey: DefaultsKey.urlSanitizerSites) == nil,
                         "an untouched setup stores nothing and reads as the built-ins")
            defaults.removePersistentDomain(forName: suiteName)
        }
        suite.expect(Defaults.registeredDefaults[DefaultsKey.urlSanitizerAutoRemove] as? Bool == true,
                     "Remove trackers automatically starts on, as cleaning always was automatic")

        // MARK: Copy

        for language in AppLanguage.allCases {
            let strings = FeatureStrings.urlSanitizer(language)
            let reference = FeatureStrings.urlSanitizer(.enUS)
            let values = Mirror(reflecting: strings).children.compactMap { $0.value as? String }
            let referenceValues = Mirror(reflecting: reference).children.compactMap { $0.value as? String }
            suite.expect(values.count == referenceValues.count && values.allSatisfy { !$0.isEmpty },
                         "every URL Sanitizer string is filled in for \(language.rawValue)")
            func specifiers(_ text: String) -> [String] {
                let pattern = try? NSRegularExpression(pattern: "%(?:\\d\\$)?[@d]")
                return pattern?.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    .compactMap { Range($0.range, in: text).map { String(text[$0]) } }.sorted() ?? []
            }
            let mismatched = zip(values, referenceValues).filter { specifiers($0) != specifiers($1) }.map(\.0)
            suite.expect(mismatched.isEmpty, "\(language.rawValue) URL Sanitizer strings keep their placeholders: \(mismatched)")
            suite.expect(!Strings.localized(language).urlCleanerName.isEmpty,
                         "the page has a name in \(language.rawValue)")
        }
        let english = FeatureStrings.urlSanitizer(.enUS)
        expectEqual(english.trackerCount(1, .enUS), "1 tracker", "one tracker")
        expectEqual(english.trackerCount(2, .enUS), "2 trackers", "two trackers")
        let russian = FeatureStrings.urlSanitizer(.ru)
        expectEqual([1, 3, 5, 11, 21, 22].map { russian.trackerCount($0, .ru) },
                    ["1 трекер", "3 трекера", "5 трекеров", "11 трекеров", "21 трекер", "22 трекера"],
                    "Russian picks the form by the last digits")
        let slovak = FeatureStrings.urlSanitizer(.sk)
        expectEqual([1, 3, 21].map { slovak.trackerCount($0, .sk) },
                    ["1 sledovač", "3 sledovače", "21 sledovačov"], "Slovak picks the form by the whole number")
        expectEqual(Strings.enUS.urlCleanerName, "URL Sanitizer", "the page is called URL Sanitizer")
    }
}
