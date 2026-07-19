//
//  CrisisResources.swift
//  Dino
//
//  HUMAN-VERIFIED regional crisis resource directory, shipped in the binary.
//  • NEVER scraped, never AI-generated, never fetched remotely.
//  • Changes ONLY by code review — every entry carries its authoritative
//    source URL as a comment for future re-verification.
//  • Region comes from Locale.current.region (device setting): no location
//    permission, works offline.
//  • KR danuri label + JP details localized; action verbs / fallback line /
//    emergency footer / international details wrapped String(localized:)
//    by owner gate 2026-07-16 (crisis localization arc). Numbers unchanged.
//  • Hours rule (owner-approved): any entry whose 24/7 status is not
//    verified ships WITHOUT the 24h badge and says "hours vary" —
//    understate, never overstate availability.
//

import Foundation

struct RegionalResource {
    enum Kind {
        case call        // contact = dialable number
        case text        // contact = sms number, smsBody = keyword
        case whatsapp    // contact = international number, digits only
        case link        // contact = https url
    }

    let name: String
    let kind: Kind
    let contact: String
    var smsBody: String? = nil
    let detail: String       // lowercase, includes hours; "hours vary" when unverified
    let is24h: Bool
    /// Optional tap-to-text alternative for lines that answer both ways
    /// (e.g. US 988). Rendered as the hero card's quiet secondary action.
    var textNumber: String? = nil

    var secondaryURL: URL? {
        textNumber.flatMap { URL(string: "sms:" + $0.filter { $0.isNumber || $0 == "+" }) }
    }

    var secondaryLabel: String? {
        textNumber.map { String(localized: "text \($0) instead") }
    }

    var actionURL: URL? {
        switch kind {
        case .call:
            return URL(string: "tel://" + contact.filter { $0.isNumber || $0 == "+" })
        case .text:
            let num = contact.filter { $0.isNumber || $0 == "+" }
            if let body = smsBody { return URL(string: "sms:\(num)&body=\(body)") }
            return URL(string: "sms:" + num)
        case .whatsapp:
            return URL(string: "https://wa.me/" + contact.filter { $0.isNumber })
        case .link:
            return URL(string: contact)
        }
    }

    var actionLabel: String {
        switch kind {
        case .call:     return String(localized: "call \(contact)")
        case .text:     return smsBody.map { String(localized: "text \($0) to \(contact)") }
                            ?? String(localized: "text \(contact)")
        case .whatsapp: return String(localized: "whatsapp \(contact)")
        case .link:     return String(localized: "open \(URL(string: contact)?.host ?? contact)")
        }
    }
}

enum CrisisResources {

    /// Warm line above the international fallback block.
    static let fallbackLine = String(localized: "wherever you are, help exists. these directories can find a line close to you 🌍")

    /// Region-neutral emergency footer (replaces the old US-only 911 line).
    static let emergencyFooter = String(localized: "if you are in immediate danger, please call your local emergency number.")

    /// Resolves the device region to its resource set. Unknown/missing region
    /// falls back to the international block — never an empty screen.
    static func resources(for regionCode: String?) -> (list: [RegionalResource], isFallback: Bool) {
        guard let code = regionCode?.uppercased(), code.count == 2,
              code.allSatisfy({ $0.isLetter && $0.isASCII }),
              let list = directory[code] else {
            return (international, true)
        }
        return (list, false)
    }

    /// Universal fallback — shown for any region not in the directory.
    static let international: [RegionalResource] = [
        // source: https://findahelpline.com
        RegionalResource(name: "find a helpline", kind: .link, contact: "https://findahelpline.com",
                         detail: String(localized: "crisis lines for over 130 countries"), is24h: true),
        // source: https://befrienders.org
        RegionalResource(name: "befrienders worldwide", kind: .link, contact: "https://befrienders.org",
                         detail: String(localized: "emotional support centres around the world"), is24h: true),
        // source: https://www.iasp.info/suicidalthoughts/
        RegionalResource(name: "iasp crisis centres", kind: .link, contact: "https://www.iasp.info/suicidalthoughts/",
                         detail: String(localized: "the international association for suicide prevention directory"), is24h: true),
    ]

    /// ISO 3166-1 alpha-2 → verified resources. Owner-reviewed 2026-07-09;
    /// PL, TH, ID added by owner review 2026-07-15 (gate 1, 2.0.1 hotfix).
    static let directory: [String: [RegionalResource]] = [
        "US": [
            // source: https://988lifeline.org — call and text both official
            // (owner-approved data change 2026-07-10: secondary text action)
            RegionalResource(name: "988 suicide & crisis lifeline", kind: .call, contact: "988",
                             detail: "call or text 988, free and confidential", is24h: true,
                             textNumber: "988"),
            // source: https://www.crisistextline.org
            RegionalResource(name: "crisis text line", kind: .text, contact: "741741", smsBody: "HOME",
                             detail: "a real human answers", is24h: true),
            // source: https://www.samhsa.gov/find-help/national-helpline
            RegionalResource(name: "samhsa helpline", kind: .call, contact: "1-800-662-4357",
                             detail: "treatment referrals, free and confidential", is24h: true),
            // source: https://www.nami.org/help
            RegionalResource(name: "nami helpline", kind: .call, contact: "1-800-950-6264",
                             detail: "weekdays 10am to 10pm et", is24h: false),
        ],
        "CA": [
            // source: https://988.ca
            RegionalResource(name: "988 suicide crisis helpline", kind: .call, contact: "988",
                             detail: "call or text 988, english and french", is24h: true),
            // source: https://kidshelpphone.ca
            RegionalResource(name: "kids help phone", kind: .text, contact: "686868", smsBody: "CONNECT",
                             detail: "for young people, by text", is24h: true),
        ],
        "GB": [
            // source: https://www.samaritans.org
            RegionalResource(name: "samaritans", kind: .call, contact: "116 123",
                             detail: "free to call, always someone there", is24h: true),
            // source: https://giveusashout.org
            RegionalResource(name: "shout", kind: .text, contact: "85258", smsBody: "SHOUT",
                             detail: "free crisis support by text", is24h: true),
            // source: https://www.mind.org.uk
            RegionalResource(name: "mind infoline", kind: .call, contact: "0300 123 3393",
                             detail: "weekdays 9am to 6pm", is24h: false),
        ],
        "IE": [
            // source: https://www.samaritans.org/ireland
            RegionalResource(name: "samaritans", kind: .call, contact: "116 123",
                             detail: "free to call, always someone there", is24h: true),
            // source: https://www.textaboutit.ie
            RegionalResource(name: "text about it", kind: .text, contact: "50808", smsBody: "HELLO",
                             detail: "free crisis support by text", is24h: true),
            // source: https://www.pieta.ie
            RegionalResource(name: "pieta", kind: .call, contact: "1800 247 247",
                             detail: "suicide and self harm support", is24h: true),
        ],
        "AU": [
            // source: https://www.lifeline.org.au
            RegionalResource(name: "lifeline", kind: .call, contact: "13 11 14",
                             detail: "crisis support, any time", is24h: true),
            // source: https://www.lifeline.org.au/crisis-text
            RegionalResource(name: "lifeline text", kind: .text, contact: "0477 13 11 14",
                             detail: "crisis support by text", is24h: true),
            // source: https://www.beyondblue.org.au
            RegionalResource(name: "beyond blue", kind: .call, contact: "1300 22 4636",
                             detail: "anxiety and depression support", is24h: true),
        ],
        "NZ": [
            // source: https://1737.org.nz
            RegionalResource(name: "need to talk? 1737", kind: .call, contact: "1737",
                             detail: "call or text 1737, free", is24h: true),
            // source: https://www.lifeline.org.nz
            RegionalResource(name: "lifeline aotearoa", kind: .call, contact: "0800 543 354",
                             detail: "crisis support, any time", is24h: true),
        ],
        "IN": [
            // source: https://telemanas.mohfw.gov.in
            RegionalResource(name: "tele manas", kind: .call, contact: "14416",
                             detail: "free, in 20 languages", is24h: true),
            // source: https://icallhelpline.org
            RegionalResource(name: "icall", kind: .call, contact: "9152987821",
                             detail: "monday to saturday, hours vary", is24h: false),
        ],
        "JP": [
            // source: https://www.since2011.net/yorisoi/
            RegionalResource(name: "よりそいホットライン", kind: .call, contact: "0120-279-338",
                             detail: "無料・秘密厳守、受付時間はさまざま", is24h: false),
            // source: https://www.inochinodenwa.org
            RegionalResource(name: "いのちの電話", kind: .call, contact: "0570-783-556",
                             detail: "午前10時から午後10時まで", is24h: false),
        ],
        "KR": [
            // source: https://www.mohw.go.kr (109 unified line, launched 2024; verified 2026-07-09)
            RegionalResource(name: "자살예방상담전화", kind: .call, contact: "109",
                             detail: "언제든지, 무료", is24h: true),
            // source: https://www.liveinkorea.kr (danuri multilingual; verified 2026-07-09)
            RegionalResource(name: "다누리콜센터 (danuri)", kind: .call, contact: "1577-1366",
                             detail: "여러 언어로 도움을 받을 수 있어요", is24h: true),
        ],
        "SG": [
            // source: https://www.sos.org.sg (verified 2026-07-09)
            RegionalResource(name: "samaritans of singapore", kind: .call, contact: "1767",
                             detail: "free and confidential", is24h: true),
            // source: https://www.sos.org.sg (caretext; verified 2026-07-09)
            RegionalResource(name: "sos caretext", kind: .whatsapp, contact: "6591511767",
                             detail: "crisis support over whatsapp", is24h: true),
        ],
        "PH": [
            // source: https://ncmh.gov.ph/contact-us/ (verified 2026-07-09)
            RegionalResource(name: "ncmh crisis hotline", kind: .call, contact: "1553",
                             detail: "landline toll free nationwide", is24h: true),
        ],
        "MY": [
            // source: https://www.befrienders.org.my
            RegionalResource(name: "befrienders kl", kind: .call, contact: "03-7627 2929",
                             detail: "emotional support, any time", is24h: true),
            // source: https://www.moh.gov.my (HEAL line)
            RegionalResource(name: "heal line", kind: .call, contact: "15555",
                             detail: "ministry of health support, hours vary", is24h: false),
        ],
        "TH": [
            // source: https://thailand.go.th/issue-focus-detail/001_07_045 (dmh 1323)
            // portal: https://1323alltime.camri.go.th (owner verified 2026-07-15)
            RegionalResource(name: "สายด่วนสุขภาพจิต 1323", kind: .call, contact: "1323",
                             detail: "ฟรี ตลอด 24 ชั่วโมง", is24h: true),
        ],
        "ID": [
            // source: https://kesprimkom.kemkes.go.id/konten/158/151/0/cegah-bunuh-diri-dukung-kesehatan-jiwa-kenali-layanan-healing119-id
            // owner decision 2026-07-15: phone entry ships WITHOUT the 24h badge
            // (house understate rule; reliability report) — tel:// cannot dial
            // extensions, so we dial 119 and the detail carries ext 8.
            RegionalResource(name: "sejiwa 119 ext 8", kind: .call, contact: "119",
                             detail: "tekan ekstensi 8, gratis", is24h: false),
            // source: https://www.healing119.id (kemenkes online service; owner verified 2026-07-15)
            RegionalResource(name: "healing119.id", kind: .link, contact: "https://www.healing119.id",
                             detail: "layanan daring kemenkes", is24h: true),
        ],
        "HK": [
            // source: https://shallwetalk.hk (18111 mental health support hotline)
            RegionalResource(name: "mental health support hotline", kind: .call, contact: "18111",
                             detail: "government support line, hours vary", is24h: false),
            // source: https://samaritans.org.hk
            RegionalResource(name: "the samaritans hong kong", kind: .call, contact: "2896 0000",
                             detail: "multilingual emotional support", is24h: true),
        ],
        "TW": [
            // source: https://www.mohw.gov.tw (1925 安心專線; verified 2026-07-09)
            RegionalResource(name: "安心專線", kind: .call, contact: "1925",
                             detail: "免費, 隨時撥打", is24h: true),
            // source: https://www.life1995.org.tw
            RegionalResource(name: "生命線", kind: .call, contact: "1995",
                             detail: "hours vary", is24h: false),
        ],
        "DE": [
            // source: https://www.telefonseelsorge.de
            RegionalResource(name: "telefonseelsorge", kind: .call, contact: "0800 111 0 111",
                             detail: "kostenlos und anonym", is24h: true),
            // source: https://www.telefonseelsorge.de
            RegionalResource(name: "telefonseelsorge (zweite nummer)", kind: .call, contact: "0800 111 0 222",
                             detail: "kostenlos und anonym", is24h: true),
        ],
        "FR": [
            // source: https://3114.fr
            RegionalResource(name: "le 3114", kind: .call, contact: "3114",
                             detail: "gratuit et confidentiel", is24h: true),
        ],
        "ES": [
            // source: https://www.sanidad.gob.es/linea024/home.htm
            RegionalResource(name: "línea 024", kind: .call, contact: "024",
                             detail: "gratuita y confidencial", is24h: true),
        ],
        "IT": [
            // source: https://www.telefonoamico.it — owner decision 2026-07-09: ship
            // 02 2327 2327 ONLY; the old 199 284 284 is a deprecated premium-rate
            // line and must never ship.
            RegionalResource(name: "telefono amico", kind: .call, contact: "02 2327 2327",
                             detail: "10am to midnight", is24h: false),
        ],
        "NL": [
            // source: https://www.113.nl
            RegionalResource(name: "113 zelfmoordpreventie", kind: .call, contact: "0800-0113",
                             detail: "gratis, ook via 113", is24h: true),
        ],
        "SE": [
            // source: https://mind.se/sjalvmordslinjen/
            RegionalResource(name: "mind självmordslinjen", kind: .call, contact: "90101",
                             detail: "hours vary", is24h: false),
        ],
        "PL": [
            // source: https://liniawsparcia.pl (centrum wsparcia, fundacja itaka)
            // gov corroboration: https://www.gov.pl/web/kppsp-limanowa/linia-bezposredniego-wsparcia-dla-osob-w-stanie-kryzysu-psychicznego
            // (owner verified 2026-07-15)
            RegionalResource(name: "centrum wsparcia", kind: .call, contact: "800 70 2222",
                             detail: "bezpłatna, całodobowa", is24h: true),
        ],
        "BR": [
            // source: https://cvv.org.br
            RegionalResource(name: "cvv", kind: .call, contact: "188",
                             detail: "gratuito, a qualquer hora", is24h: true),
        ],
        "MX": [
            // source: https://findahelpline.com/organizations/linea-de-la-vida (verified 2026-07-09)
            RegionalResource(name: "línea de la vida", kind: .call, contact: "800 911 2000",
                             detail: "gratuita y confidencial", is24h: true),
        ],
        "AR": [
            // source: https://www.asistenciaalsuicida.org.ar (135 covers caba/gba)
            RegionalResource(name: "línea 135", kind: .call, contact: "135",
                             detail: "gratuita desde caba y gba", is24h: true),
            // source: https://www.asistenciaalsuicida.org.ar (nationwide number)
            RegionalResource(name: "asistencia al suicida (todo el país)", kind: .call, contact: "(011) 5275-1135",
                             detail: "desde todo el país", is24h: true),
        ],
        "ZA": [
            // source: https://www.sadag.org
            RegionalResource(name: "sadag helpline", kind: .call, contact: "0800 567 567",
                             detail: "free mental health support", is24h: true),
            // source: https://www.sadag.org
            RegionalResource(name: "sadag sms", kind: .text, contact: "31393",
                             detail: "they call you back", is24h: false),
        ],
    ]
}
