#import "@preview/fletcher:0.5.8" as fletcher: *

#import "@preview/diatypst:0.9.1": *

#import "@preview/tiaoma:0.3.0"

#set text(font: "Roboto", lang: "de")

#let tc = rgb("6367FF").darken(10%);
#let tcl = rgb("6367FF").lighten(80%);

#set list(spacing: 1em)
#set enum(spacing: 1em)

#show: slides.with(
  title: "Entwicklung eines kryptografisch sicheren und modernen Messenger-Dienstes", // Required
  subtitle: "unter eigenständiger Implementierung eines TLS-ähnlichen Protokolls",
  authors: ("Anton Aparin"),
  ratio: 16/9,
  layout: "medium",
  title-color: tc,
  toc: false,
  footer: false,
)

== Inhalt

#align(center + horizon)[
  #set box(
    inset: 1em,
    fill: tcl,
    radius: 1em,
    width: 50%
  )

  #box[Ausgangslage & Fragestellung]
  
  #box[Idee und Vorgehensweise]
  
  #box[Entwicklung der Chat-App]

  #box[Ergebnisse & Sicherheitsanalyse]

  #box[Fazit und Ausblick]
]

== Idee & Ziel

#v(0.5cm)

- HTTPS wird von allen verwendet.
- Nur von sehr wenigen verstanden.
- Auch für Software-Entwickler meistens eine "Blackbox".
- *Kann ich auch selbst ein sicheres Protokoll für eine Messenger-App implementieren?*

#figure(
  image("secure.png", height: 4cm),
  caption: [Schlosssymbol in Firefox],
)

// #table(
//   columns: (1fr, 1fr, 1fr, 1fr),
//   [Vertraulichkeit],
//   [Integrität],
//   [Authentizität],
//   [Forward Secrecy],
//   [Nur Sender und Empfänger lesen mit.],
//   [Nachrichten können unbemerkt nicht verändert werden.],
//   [Sicherstellen, dass der Partner der ist, für den er sich ausgibt.],
//   [Auch wenn ein Langzeitschlüssel gestohlen wird, bleiben alte Nachrichten sicher.],
// )

== Methodik

#v(.5cm)

#align(center)[
  #set text(size: 14pt)
  
  #diagram(
    spacing: (.5cm, 2cm),
    // debug: true,
    node-shape: fletcher.shapes.chevron,
    node-fill: tcl,
    node-stroke: tc,
    node-inset: .8em,
    node((0, 0), [*Theorie*]),
    node((1, 0), [*Design*]),
    node((2, 0), [*Implementierung*]),
    node((3, 0), [*Test*]),
  )
]

+ *Theorie*: Analyse von TLS und Algorithmen.
+ *Design*: Entwurf der Anwendung, verwendete Technologien, Architektur.
+ *Implementierung*: Alle Komponenten wurden Programmiert.
+ *Test*: Pen-Testing durchgeführt, um Sicherheit der Anwendung zu prüfen.

- *Hauptquellen*:
  - Network Security: Private Communication in a Public World, C. Kaufman
  - Cloudflare
- Auch viel *eigene Erfahrung* im Programmieren.

== Theorie

#v(0.5cm)

- TLS = Modernes Protokoll, Standard für sichere Datenübertragung #footnote()[vgl. #cite(<Kaufman2022>, form: "prose") #cite(<tls>, form: "prose")]
- HTTP + TLS = HTTPS

#align(center)[
  #diagram(
    spacing: (32mm, 10mm),
    // debug: true,
    node([Client], enclose: ((0,-1), (0,3)), fill: tcl, stroke: tc),
    node([Server], enclose: ((2,-1), (2,3)), fill: tcl, stroke: tc),
    edge((0,0), "-|>", (2, 0), [Hallo von Client]),
    edge((0,1), "<|-", (2, 1), [Hallo von Server]),
    edge((0,2), "<|-|>", (2, 2), [Datenübertragung]),
  )
]

#pagebreak()

#v(0.5cm)

- Die 4 Sicherheitskonzepte von TLS sind:
  + *Vertraulichkeit*: Nur Sender und Empfänger lesen mit.
  + *Integrität*: Nachrichten können unbemerkt nicht verändert werden.
  + *Authentizität*: Sicherstellen, dass der Partner der ist, für den er sich ausgibt.
  + *Forward Secrecy*: Auch wenn ein Langzeitschlüssel gestohlen wird, bleiben alte Nachrichten sicher.

== Architektur & Design

#align(center)[
  #diagram(
    spacing: (10mm, 10mm),
    node-stroke: tc,
    node-fill: tcl,
    node-inset: .5em,
    node((0,0), [*Frontend-WASM* \ (Benutzer-Logik)], name: <wasm>),
    node((1,0), [*Frontend-Vue* \ (Benutzeroberfläche)], name: <vue>),
    node((2,0), [*Proxy* \ (Weiterleitung)], name: <proxy>),
    node((3,0), [*Protocol* \ (Definitionen)], name: <protocol>),
    node(enclose: (<wasm>, <vue>, <proxy>, <protocol>), shape: shapes.bracket.with(label: [Die 4 Komponenten der Anwendung], dir: top))
  )

  #v(0.5cm)
  
  #diagram(
    spacing: (18mm, 10mm),
    node-stroke: tc,
    node-fill: tcl,
    node((0,1), [*Frontend-WASM*], name: <wasm>),
    node((0,0), [*Frontend-Vue*], name: <vue>),
    node((1,0), [*Proxy*], name: <proxy>),
    node((2,0), [*Andere Nutzer*], name: <other>),
    node([*Browser*], enclose: (<wasm>, <vue>), stroke: green, fill: green.lighten(90%), name: <browser>),
    edge(<wasm>, "-|>", <vue>, bend: 15deg, shift: 1cm),
    edge(<wasm>, "<|-", <vue>, bend: -15deg, shift: -1cm),
    edge(<vue>, "<|-|>", <proxy>),
    edge(<other>, "<-->", <proxy>),
    node(enclose: (<browser>, <proxy>, <other>), shape: shapes.bracket.with(label: [Datenfluss der Anwendung], dir: top))
  )
]

#underline[Verwendete Technologien]: *Rust* (Programmiersprache), *Vue* (JavaScript-Framework),\ *WASM* (binäres Instruktionsformat), *JavaScript* (Skriptsprache)

== Implementierung & Hürden

#v(0.5cm)

- Zunächst die wichtigsten Teile von `protocol` implementiert.
- Danach an allen Teilen gleichzeitig weitergearbeitet.

#align(center)[
  3 mögliche Zustände eines Chats (Zustandsmaschine)
  
  #diagram(
    spacing: (10mm, 10mm),
    node-stroke: tc,
    node-fill: tcl,
    node-inset: .5em,
    node((0,0), [*Unbekannt*], name: <1>),
    node((1,0), [*Initiiert*], name: <2>),
    node((2,0), [*Verschlüsselt*], name: <3>),
    node(enclose: (<1>, <2>, <3>), fill: green.lighten(90%), stroke: green)
  )
]

- Alle Fehler müssen behoben werden.
- *Rust* war aufgrund von gutem Error-Handling von großem Vorteil.
- Auch *State-Mismatches* müssen genau definiert sein.

== Codebeispiel

#v(0.5cm)

```rust
let message = match packet.message.decrypt(cipher, packet.nonce) {
    Ok(m) => m,
    Err(e) => {
        message_updates.push(MessageUpdateToFrontend {
            chat_id: packet.id.to_string(),
            message: Message::System(format!(
                "{} attempted to send message but decryption failed: {}",
                to_hex(&packet.sender_ver_key.to_bytes()),
                e
            )),
        });
        return Ok((message_updates, None));
    }
};
```

== Transparenz durch Versionskontrolle

#v(0.5cm)

- *Git & GitHub*
- *Nachvollziehbarkeit*: 30 Commits dokumentieren den gesamten Entwicklungsprozess.
- *Open Source*: Der vollständige Quellcode und die Dokumentation sind öffentlich zugänglich.
- *Fehlermanagement*: Systematische Behebung von Bugs durch Versionshistorie.
#figure(
  image("GitHub2.png", height: 4cm),
  caption: [GitHub Commits vom 31. Oktober 2025]
)

== Validierung & Tests

#v(0.5cm)

#align(center)[
  #diagram(
    spacing: (18mm, 10mm),
    node-stroke: tc,
    node-fill: tcl,
    node((0,0), [*Client*], name: <vue>),
    node((1,0), [*Burp-Suite*], name: <burp>, stroke: (dash: "dashed")),
    node((2,0), [*Proxy*], name: <proxy>),
    edge(<vue>, "<|~|>", <burp>),
    edge(<burp>, "<|~|>", <proxy>),
  )
]

#v(0.5cm)

- *Werkzeug*: Burp-Suite als Man-in-the-Middle-Proxy.
- *Test-Szenarien & Ergebnisse*:
  - *Manipulation*: Gezielte Bit-Veränderung wurde durch Integritätsprüfung (AEAD) sofort erkannt.
  - *Replay-Attacks*: Verdoppelte Pakete wurden abgelehnt.
  - *Daten-Einsicht*: Trotz vollem Zugriff auf den Datenstrom blieb der Inhalt dank E2E-Verschlüsselung unlesbar.

== Ergebnisse

#v(0.5cm)

- Quellcode, die Arbeit und eine Demo sind veröffentlicht unter \ https://aba.antonaparin.com
- Anwendung funktioniert, keine Sicherheitslücken wurden entdeckt.
- Die definierten Sicherheitspunkte wurden erfolgreich erreicht.
  + *Vertraulichkeit*: Die Nachrichten können auch vom Proxy nicht entschlüsselt werden.
  + *Integrität*: Jede Änderung wird sofort erkannt.
  + *Authentizität*: Nach dem Handshake kann niemand imitiert werden.
  + *Forward Secrecy*: Wenn zukünftig Schlüssel gestohlen werden, können Nachrichten nicht entschlüsselt werden.


== Abschluss & Reflexion

#v(0.5cm)

- "Security by Design" statt "Security by Obscurity"
- Prozess war von unerwarteten Fehlern geprägt
- Tieferes Verständnis der Technologien
- Ausblick:
  - Gruppenchats
  - Einfacheres teilen von öffentlichen Schlüsseln
  - Horizontale Skalierung
  - Wiederherstellbare Chats
- Leitfrage wurde beantwortet:
  - Eigenes Protokoll konnte implementiert werden

== Quellen

#v(0.5cm)

#bibliography("bib.bib", full: true)

#v(0.2cm)

#align(center)[
  #tiaoma.barcode("https://aba.antonaparin.com", "QRCode", options: (
    scale: 2.5
  ))
  https://aba.antonaparin.com
]