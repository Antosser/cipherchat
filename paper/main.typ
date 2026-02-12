#import "@preview/fletcher:0.5.8" as fletcher: *

#import "@preview/lovelace:0.3.0": pseudocode-list

#import "@preview/zebraw:0.5.5": *
#show: zebraw

#import "@preview/wordometer:0.1.5": word-count, total-words, total-characters

#import "@preview/tiaoma:0.3.0"

#show: word-count

#show raw.where(block: false): body => highlight(radius: 3pt, extent: 1pt, fill: luma(92%), top-edge: 1.1em, bottom-edge: -0.3em)[#body]
#show raw.where(block: true): body => [#v(1em) #body]
#show raw: set text(font: "Cascadia Code")

#show heading.where(level: 1): body => [#pagebreak() #body]

#set text(font: "Roboto", size: 12pt, lang: "de")
#set heading(numbering: "1.")
#set footnote(numbering: "1")

#import "@preview/shadowed:0.2.0": shadowed

#set table(
  stroke: none,
  gutter: 0.2em,
  fill: (x, y) =>
    if x == 0 or y == 0 { luma(92%) } else { teal.lighten(90%) },
  inset: 0.5em,
)


#show table.cell: it => {
  if it.x == 0 or it.y == 0 {
    strong(it)
  } else {
    it
  }
}

#set page(
  paper: "a4",
  margin: 2.5cm,
)

#box(width: 12cm)[
  #text(weight: "light", size: 22pt)[ABSCHLIESSENDE ARBEIT] \
  #text(size: 14pt)[im Schuljahr 2025/26]

  #v(1cm)
  
  #text(weight: "medium",size: 34pt)[Entwicklung eines kryptografisch sicheren und modernen Messenger-Dienstes]
  
  #text(size: 25pt)[unter eigenständiger Implementierung eines TLS-ähnlichen Protokolls]
  
  #v(1cm)

  vorgelegt von: \
  *Anton Aparin*

  #text(size: 15pt)[8C]

  unter Betreuung von: \
  Robin Gludovatz, BEd

  Wien, am 13.2.2026

  #text(size: 15pt, weight: "medium")[Gymnasium und Realgymnasium] \
  der Vereinigung von Ordensschulen Österreichs

  1180 Wien, Semperstraße 45 \
  Schulkennzahl: 918016
]

#place(right + horizon, dx: 1cm)[
  #image("ABA.png", height: 125%)
]

#let image(..arg) = shadowed(std.image(..arg))
#set text(top-edge: 1em)
#set par(justify: true)
#set page(numbering: "1")

#outline()

= Abstract

Diese Abschlussarbeit beschäftigt sich mit der Entwicklung einer kryptografisch sicheren und modernen Messenger-App. Ziel der Arbeit ist es, ein eigenes, TLS-ähnliches Kommunikationsprotokoll umzusetzen, um die Funktionsweise moderner Sicherheitsprotokolle besser zu verstehen. Zentral sind dabei die Sicherheitsziele Vertraulichkeit, Integrität, Authentizität und Forward Secrecy.

Zu Beginn werden die theoretischen Grundlagen der Kryptografie erläutert, darunter Hashfunktionen, digitale Signaturen, Schlüsselaustauschverfahren sowie symmetrische Verschlüsselung. Darauf aufbauend wird das Transport-Layer-Security-Protokoll (TLS) analysiert und als Grundlage für ein vereinfachtes, speziell auf einen Messenger zugeschnittenes Protokoll genommen. Dieses verwendet moderne Algorithmen wie Ed25519, X25519 und AES-GCM.

Im nächsten Teil wird der Messenger vollständig implementiert. Die Architektur besteht aus einem Proxy-Backend, einem Web-Frontend sowie einer in WebAssembly ausgeführten kryptografischen Logik, die in Rust entwickelt wurde.

Abschließend wird das Protokoll in einem professionellen Penetration-Testing-Programm getestet und analysiert. Die Ergebnisse zeigen, dass das entwickelte System die definierten Sicherheitsziele erfüllt und einen funktionierenden, Ende-zu-Ende-verschlüsselten Nachrichtenaustausch ermöglicht.

= Einleitung

== Motivation

Digitale Kommunikation wurde zu einem der wichtigsten Bestandteile unseres Lebens. Nachrichten werden konstant übermittelt, ob in Messengern, E-Mails oder Social Media. Jedoch findet diese Kommunikation oft über unsichere Netzwerke statt, wie zum Beispiel öffentliche Wi-Fi-Netzwerke, in denen die Informationen *gelesen und manipuliert* werden können.

Für den Schutz der Privatsphäre, Integrität und Authentizität der Daten sind deshalb kryptografische Algorithmen unverzichtbar.

Moderne Messenger wie Signal und WhatsApp setzen komplexe Sicherheitsprotokolle ein, die sichere, verschlüsselte Kanäle herstellen. Zentral ist dabei das *Transport-Layer-Security-Protokoll (TLS)*. Dieses ist ein Teil des bekannteren *Hypertext-Transfer-Protocol-Secure (HTTPS)* und wird in annähernd allen Internetanwendungen eingesetzt. Die Entwicklung solcher Protokolle ist jedoch technisch sehr kompliziert und bleibt auch für die meisten Software-Entwickler meistens eine "Blackbox".

Aus diesem Grund bietet die Entwicklung eines eigenen Messengers auf Basis eines *TLS-ähnlichen Protokolls* eine gute Möglichkeit, verschiedene kryptografische Algorithmen praktisch anzuwenden und zu verstehen. Das Projekt ist gleichzeitig sehr herausfordernd, denn es erfordert sowohl tiefgehendes theoretisches Wissen als auch praktische Programmierfähigkeiten.

== Zielsetzung <ziele>

Das Ziel dieser Arbeit ist die Entwicklung eines TLS-ähnlichen Protokolls, das einen sicheren Kanal für die Kommunikation von zwei Partnern über ein unsicheres Netzwerk herstellen kann. Es soll anschließend in einem selbst entwickelten Messenger implementiert werden.

Unter Sicherheit wird verstanden, dass die Nachrichten
- geheim bleiben (*Vertraulichkeit*)
- nicht verändert werden können (*Integrität*)
- wirklich von der richtigen Person stammen (*Authentizität*)
- auch später mit gestohlenen Schlüsseln nicht entschlüsselt werden können (*Forward Secrecy*) @tls

= Grundlagen und Stand der Technik

== Kryptografie

In dieser Arbeit werden mehrere kryptografische Algorithmen für verschiedene Zwecke verwendet, zum Beispiel zum Signieren, Verschlüsseln, Schlüsselaustausch oder Haschen.

=== Hashfunktionen

Eine Hashfunktion ist ein Verfahren, das Text oder Bytes beliebiger Länge auf eine Ausgabe fester Länge abbildet. Diese Ausgabe bezeichnet man als Digest oder Hashwert. Solche Funktionen werden für Integritätsprüfungen, digitale Signaturen und Passwortspeicherungen verwendet. Ein Beispiel einer solchen Funktion ist *SHA256 (Secure Hash Algorithm 256)*. Sie nimmt eine beliebige Anzahl an Bytes ein und gibt genau 256 Bits (32 Bytes) zurück.

*Eigenschaften*:

+ *Determinismus*: Bei gleichem Input bekommt man immer denselben Output.
+ *Schnelle Berechenbarkeit*.
+ *Einwegfunktion*: Während es sehr einfach ist, den Digest eines Wertes zu berechnen, ist das Berechnen des Inputs aus dem Digest praktisch unmöglich#footnote[Damit ist gemeint, dass die Rechnung auch auf den schnellsten Computern _sehr_ lange dauern wird.].
+ *Kollisionsresistenz*: Es ist praktisch unmöglich, zwei verschiedene Eingaben zu finden, die denselben Digest erzeugen.
+ *Avalanche-Effekt*: Wenn ein einzelnes Bit der Eingabe geändert wird, wird eine völlig andere Ausgabe erzeugt. @Kaufman2022, @avalanche

=== Signaturalgorithmen

==== Grundprinzip

Wenn man eine Nachricht im Internet verschickt, will man nicht nur, dass sie geheim bleibt, sondern auch, dass der Empfänger sicherstellen kann, dass sie von der richtigen Person kommt (*Authentizität*) und auf dem Weg nicht verändert wurde (*Integrität*).

Digitale Signaturen basieren auf asymmetrischer Kryptografie. Das heißt, dass jeder Benutzer

- einen *geheimen Schlüssel* (besitzt nur der Sender)
- einen dazugehörigen *öffentlichen Schlüssel* (jeder hat Zugriff)

besitzt. Der Sender erstellt eine Signatur über eine Nachricht und verwendet dabei den geheimen Schlüssel. Der Empfänger kann dann mit dem öffentlichen Schlüssel des Senders prüfen, ob die Nachricht tatsächlich exakt so von dem angegebenen Sender gesendet wurde.

==== Ablauf

+ Der Sender macht die Nachricht bereit.
+ Der Sender berechnet den Hash über die Nachricht.
+ Der Sender verschlüsselt den Hash mit dem geheimen Schlüssel. Das wird dann zur Signatur.
+ Der Sender schickt sowohl die Nachricht als auch die Signatur an den Empfänger.
+ Der Empfänger berechnet ebenfalls den Digest der Nachricht.
+ Der Empfänger entschlüsselt die Signatur und vergleicht sie mit dem berechneten Hash.
+ Sind sie gleich, dann wurde bestätigt, dass die Nachricht tatsächlich unverändert vom richtigen Sender kommt. @tls

==== Typische Algorithmen

- *RSA-Signatur*: Basiert auf Primzahlen, ist aber nicht modern und relativ langsam.
- *DSA (Digital Signature Algorithm)*: Wurde speziell für das Signieren entwickelt.
- *ECDSA*: Wie DSA, basiert aber auf elliptischen Kurven.
- *EdDSA (z. B. Ed25519)*: Moderne Variante, basiert auch auf elliptischen Kurven, sehr sicher und effizient. Daher wird er heutzutage überall (und in dieser Arbeit) oft genutzt. @Kaufman2022

=== Schlüsselaustauschalgorithmen

==== Problemstellung

Wenn zwei Personen im Internet geheim kommunizieren wollen, brauchen beide *denselben geheimen Schlüssel*. Aber wie können sie diesen über das Internet austauschen, ohne dass ihn jemand, der zuhört, diesen abhören kann?

Das lösen *Schlüsselaustauschalgorithmen*.

==== Idee

+ Jeder Teilnehmer generiert einen geheimen Schlüssel.
+ Jeder Teilnehmer berechnet den öffentlichen Schlüssel aus dem geheimen Schlüssel.
+ Die öffentlichen Schlüssel werden ausgetauscht.
+ Danach können beide Teilnehmer denselben Wert berechnen, aber ein Angreifer, der keine geheimen Schlüssel besitzt, kommt nicht an den Wert.
+ Aus diesem Wert wird der _Cipher_, der geheime asymmetrische Schlüssel, erstellt.

==== Moderne Varianten

- *ECDH (Elliptic Curve Diffie-Hellman)*.
- *X25519*: Moderner als ECDH, wird heutzutage überall verwendet (z. B. in TLS 1.3, Signal, WireGuard und in dieser Arbeit).

=== Symmetrische Verschlüsselungsverfahren

==== Idee

Nach einem Schlüsselaustausch haben beide Partner denselben Schlüssel und wollen Daten verschlüsseln und entschlüsseln.

Dafür wird meistens *AES (Advanced Encryption Standard)* verwendet. Es ist der weltweite Standard, der sehr effizient und zuverlässig ist.

==== AES (Advanced Encryption Standard)

+ AES teilt Daten in Blöcke von *128 Bit (16 Byte)* auf.
+ Jeder Block wird einzeln mit einem *Schlüssel (128, 192 oder 256 Bit)* verschlüsselt.
+ AES vermischt die Daten mit dem Schlüssel in mehreren Runden.
+ Am Ende erhält man zufällig aussehende Bytes, die nur mit demselben Schlüssel entschlüsselt werden können.

==== AES-GCM (AES im Galois/Counter-Mode)

AES ist nur für die Verschlüsselung verantwortlich. In der Praxis braucht man auch noch Integritätsschutz, damit man prüfen kann, ob die Nachricht verändert wurde.

Dafür nutzt man Betriebsmodi wie *GCM (Galois/Counter-Mode)*.
Dabei wird zusätzlich ein öffentlicher *Prüfwert (Tag/Nonce)* geschickt, womit die *Integrität* geprüft werden kann.

==== Anwendung

Symmetrische Verschlüsselung wird überall angewendet, wo Sicherheit und Effizienz gefragt sind. Dazu gehören *TLS 1.3* -- also *HTTPS* -- *moderne Apps* wie Signal oder WhatsApp und *diese Arbeit*.

== Angriffsmodelle

Ein gutes Protokoll muss verschiedene Attacken berücksichtigen, die auf einem öffentlichen Netz auftreten können. Folgend werden die relevanten Attacken aufgezählt.

=== Man-in-the-Middle (MITM)

Bei *MITM* dringt ein Angreifer zwischen den Client und den Server. Er kann alle Nachrichten, die gesendet werden, lesen, nach Bedarf verändern und neue Nachrichten erzeugen.

Das kann zum Beispiel vorkommen, wenn ein Angreifer auf einem öffentlichen Wi-Fi-Netz den Router imitiert und alle Verbindungen im Netz zuerst durch sich laufen lässt.

=== Replay-Attacken

Bei *Replay-Angriffen* wiederholt ein Angreifer bereits gesendete Nachrichten, sodass sie bei dem Empfänger doppelt ankommen. Das kann dazu führen, dass Befehle (wie Banktransaktionen) *doppelt ausgeführt werden*.

=== Downgrade-Attacken

Ein *Downgrade-Angriff* versucht, die verwendeten Algorithmen auf eine ältere, *unsichere Version* zu zwingen, um später einfacher an die Schlüssel zu kommen.

=== Key Compromise und Forward Secrecy

Wenn ein Schlüssel in der Zukunft kompromittiert wird, kann es einem Angreifer erlauben, alle verschlüsselten Nachrichten zu lesen.

Das kann mit *RSA* (*Rivest-Shamir-Adleman* -- ein alter Algorithmus für asymmetrische Kryptografie) auftreten.

Moderne Protokolle können diese Art von Angriffen verhindern, indem sie ephemerale, kurzlebige Schlüssel verwenden. Das Konzept wird *Forward Secrecy* genannt. @tls_mdn

== TLS im Überblick

TLS ist der heutige Standard, um Daten sicher im Internet zu übertragen.

Mit den obengenannten Algorithmen stellt TLS *Vertraulichkeit, Integrität und Authentizität* sicher.

Um dies zu erreichen, wird TLS in zwei Phasen gegliedert: *Handshake* und *Datenübertragung*.

=== Handshake

Der TLS-Handshake passiert erst nach dem TCP-Handshake. So kann beispielsweise ein TLS 1.2 Handshake verfolgen:

#figure(caption: [TLS 1.2 Handshake])[
  #diagram(
    spacing: (32mm, 10mm),
    // debug: true,
    node([Client], enclose: ((0,-1), (0,8)), fill: teal.lighten(90%), stroke: teal),
    node([Server], enclose: ((2,-1), (2,8)), fill: teal.lighten(90%), stroke: teal),
    edge((0,0), "-|>", (2, 0), [ClientHello]),
    edge((0,1), "<|-", (2, 1), [ServerHello]),
    edge((0,2), "<|-", (2, 2), [Zertifikat + Signatur]),
    edge((0,3), "-|>", (2, 3), [ClientKeyExchange (DH-Param.)]),
    edge((0,4), "<|-", (2, 4), [ServerKeyExchange]),
    edge((0,5), "--", (2, 5), [Schlüsselberechnung]),
    edge((0,6), "-|>", (2, 6), [Finished (bereit)]),
    edge((0,7), "<|-", (2, 7), [Finished]),
  )
]<tls12>
// chatgpt

+ *ClientHello*: Der Client meldet sich mit seiner unterstützten TLS-Version, einem Zufallswert (*Client-Random*) und einer Liste von möglichen Cipher-Suites.
+ *ServerHello*: Der Server antwortet mit seiner ausgewählten Cipher-Suite, einem eigenen Zufallswert (*Server-Random*) und seinem Zertifikat.
+ *Server-Signatur*: Der Server signiert die bisherigen Nachrichten, damit der Client die Echtheit prüfen kann.
+ *Signaturprüfung*: Der Client überprüft das Zertifikat und die Signatur #sym.arrow Authentizität ist gewährleistet.
+ *Schlüsselaustausch*: Der Client sendet seine Diffie-Hellman-Parameter, der Server seine. Beide können nun unabhängig voneinander den Premaster-Secret berechnen.
+ *Session Keys*: Aus Premaster-Secret, Client-Random und Server-Random werden symmetrische Schlüssel generiert.
+ *Finished-Nachrichten*: Beide bestätigen, dass sie denselben Schlüssel besitzen und nun mit verschlüsselter Kommunikation fortfahren können.
+ Ab jetzt: Die Datenübertragung läuft symmetrisch verschlüsselt (z. B. mit AES-GCM). @tls

=== Datenübertragung
- Nachrichten werden mit dem symmetrischen Schlüssel verschlüsselt/entschlüsselt.
- Jede Nachricht enthält eine integrierte Authentifizierung, wie z. B. ein Nonce in AES-GCM.
- Zähler und Nonces verhindern, dass alte Nachrichten erneut wiedergespielt werden (Replay-Schutz).

=== Sicherheitsmerkmale

- *Forward-Secrecy*: Auch wenn ein geheimer Schlüssel zukünftig kompromittiert wird, können die Nachrichten nicht entschlüsselt werden, da für jede Verbindung ein eigener symmetrischer Schlüssel verwendet wird.
- *Downgrade-Schutz*: Angreifer können die Verbindung nicht auf unsichere Algorithmen zwingen.

= Planung

Als Erstes ist es wichtig, zu definieren, welche Funktionen die Chat-App haben soll, welche Sicherheitsziele die App anstreben soll, was nicht Teil der App ist und welche Technologien am besten zu diesen Zielen passen.

== Anforderungen

Die Kernfunktionen der Anwendung sind:

- Sichere *Ende-zu-Ende-Verschlüsselung* von Nachrichten.
- *Sicherer Verbindungsaufbau* (Handshake) zwischen zwei Kommunikationspartnern.
- Ein minimales, aber funktionierendes *Frontend*, ähnlich zu Telegram.
- Ein *Proxy-Server*, der die Nachrichten weiterleitet, aber keinerlei die Nachrichten auf ihrem Weg entschlüsseln oder ändern kann.

== Sicherheitsziele

Das Protokoll soll dieselben Sicherheitsziele wie TLS verfolgen, also *Vertraulichkeit, Integrität, Authentizität und Forward Secrecy*.

== Abgrenzung

Diese Aspekte werden aus dem Projekt bewusst ausgeklammert:

- Ein *Zertifikatssystem* wie bei TLS.
- Schutz gegen *Denial-of-Service-Angriffe (DOS)*.

== Technologiewahl

Zur Erreichung der Sicherheitsziele und Anforderungen wurden folgende Technologien/Sprachen ausgewählt:

- Die Programmiersprache *Rust* für das Backend und die Kryptografie-Logik. Sie ist eine der sichersten und modernsten auf der Welt und hat ein sehr praktisches Typ-System, das den Entwicklungsprozess beschleunigt und Fehler minimiert.
- *WASM (Web-Assembly)* für Krypto-Logik im Frontend, wobei der Code direkt aus *Rust* kompiliert wird.
- *Vue* als Frontend-Framework: Einfaches UI, schnelle Entwicklung.
- Ein *eigenes Protokoll* statt TLS für volle Kontrolle und als Lernebene.

== Vorgehensweise

- Entwurf der *Projektstruktur*
- Modellierung des *Kommunikationsflusses*
- *Protokolldesign* und Festlegung der Abläufe
- *Implementierung* aller Komponenten
- Durchführung von *Tests*
- *Reflexion* der Ergebnisse und Auswertung

= Design

== Architekturübersicht

=== Gesamtidee

Die Chat-App besteht aus einem Frontend mit einer Benutzeroberfläche (UI), die direkt vom User bedient wird, sowie einem Backend als zentraler Proxy. Dieser Proxy ist dafür verantwortlich, Nachrichten an den richtigen Empfänger weiterzuleiten. Direkte Verbindungen zwischen den Nutzern existieren nicht.

=== Komponenten <komponenten>

Der Code ist in 4 Komponenten unterteilt:

- *Backend*: Code, der auf einem Server läuft. Ist dafür verantwortlich, dass Nachrichten an die richtige Person weitergeleitet werden. Kann die Nachrichten nicht lesen, sondern leitet sie nur blind weiter.
- *Frontend-WASM*: Enthält die kryptografische Logik. Hier werden Nachrichten verschlüsselt, entschlüsselt und die einzelnen Protokollschritte ausgeführt.
- *Frontend-Vue*: Enthält das Design der Website und dient als Schnittstelle zwischen dem User und der Logik in *Frontend-WASM*.
- *Protocol*: Definitionen für das Protokoll, damit jeder Benutzer und der Server die Nachrichten einheitlich serialisieren.

==== Verwendete Technologien <technologien>

- *Rust*: Eine moderne Systemprogrammiersprache mit Fokus auf Sicherheit und Kontrolle. Sie eignet sich besonders gut für Kryptographie, da moderne Algorithmen gut unterstützt sind und alle auftretenden Fehler explizit behandelt werden. @rust
- *WebAssembly (WASM)*: Ein standardisiertes Bytecode-Format, das direkt im Browser ohne Sicherheitsrisiken ausgeführt werden kann. Damit kann man Rust-Code im Browser ausführen. In diesem Projekt übernimmt das kompilierte WASM die kryptographische Logik, sodass auch sie sicher und schnell ablaufen kann. @rustwasmbook
- *Vue.js*: Ein *JavaScript-Framework* zur Entwicklung reaktiver Benutzeroberflächen. Vue zeigt das UI an, stellt eine Verbindung zum Proxy her und ruft bei Bedarf Funktionen aus WASM. @vue

=== Kommunikationsfluss

Wie bereits erwähnt, findet keine direkte Verbindung zwischen den Clients statt. Stattdessen erfolgt der gesamte Nachrichtenverkehr über den Proxy.

#figure(caption: [Kommunikationsfluss Gesamtbild])[
  #diagram(
    spacing: (18mm, 10mm),
    node-stroke: teal,
    node-fill: teal.lighten(90%),
    node((0,0), [*Person 1*], name: <1>),
    node((2,0), [*Person 2*], name: <2>),
    node((0,1), [*Person 3*], name: <3>),
    node((2,1), [*Person 4*], name: <4>),
    node((1,0), [*Proxy*], name: <p>),
    edge(<p>, "<|-|>", <1>),
    edge(<p>, "<|-|>", <2>),
    edge(<p>, "<|-|>", <3>),
    edge(<p>, "<|-|>", <4>),
  )
]

Da die Herstellung einer Web-Socket-Verbindung direkt aus Web-Assembly technisch zu komplex wäre, übernimmt *Frontend-Vue* diese Aufgabe. Die in *Frontend-WASM* implementierte Kryptografie wird als _Bibliothek_ eingesetzt.

#figure(caption: [Kommunikationsfluss Frontend])[
  #diagram(
    spacing: (18mm, 10mm),
    node-stroke: teal,
    node-fill: teal.lighten(90%),
    node((0,1), [*Frontend-WASM*], name: <wasm>),
    node((0,0), [*Frontend-Vue*], name: <vue>),
    node((1,0), [*Proxy*], name: <proxy>),
    node((2,0), [*Andere Nutzer*], name: <other>),
    node([*Browser*], enclose: (<wasm>, <vue>), stroke: green, fill: green.lighten(90%)),
    edge(<wasm>, "-|>", <vue>, bend: 15deg, shift: 1cm),
    edge(<wasm>, "<|-", <vue>, bend: -15deg, shift: -1cm),
    edge(<vue>, "<|-|>", <proxy>),
    edge(<other>, "<-->", <proxy>),
  )
]

== Protokollentwurf <protokollentwurf>

Als Grundlage für das Protokoll dient TLS 1.2 (vgl. @tls12). TLS 1.3 wäre als Basis weniger optimal, da es wesentlich komplexer ist und die Adaptierung erschwert.

Damit das Protokoll zu einer Chat-App passt, wurden einige Änderungen vorgenommen:

+ Statt komplexer Zertifikate werden pure Ed25519 asymmetrische Schlüssel verwendet.
+ Beide Kommunikationspartner müssen sich gegenseitig authentifizieren. In TLS ist das optional und wird in der Praxis nur selten verwendet.
+ Da dieselbe Protokollversion und dieselben Cipher-Suits garantiert sind, müssen die Protokollversion und die Cipher-Suits nicht ausgetauscht werden. Der Handshake kann dadurch auf nur ein paar Schritte komprimiert werden.

Aus diesen Überlegungen entstand das folgende Protokoll. Dabei haben die Rollen *Client* und *Server* keine traditionelle Bedeutung, sondern nur, wer den Chat initiiert (Client) und wer darauf reagiert (Server). Die Namen SYN und ACK wurden bewusst aus TCP übernommen.

#figure(caption: [Protokollentwurf])[
  #diagram(
    spacing: (32mm, 10mm),
    // debug: true,
    node([Client], enclose: ((0,-1), (0,3)), fill: teal.lighten(90%), stroke: teal),
    node([Server], enclose: ((2,-1), (2,3)), fill: teal.lighten(90%), stroke: teal),
    edge((0,0), "-|>", (2, 0), [SYN]),
    edge((0,1), "<|-", (2, 1), [ACK]),
    edge((0,2), "<|-|>", (2, 2), [MSG]),
  )
]<proto>

+ *Handshake-Initialisierung (Client #sym.arrow Server)*
  - Der Client erzeugt eine Chat-ID, Zufallswerte und ein ephemeres Schlüsselpaar.
  - Der Client signiert die Anfrage (*SYN*) mit dem geheimen Schlüssel und sendet sie an den Server.
+ *Handshake-Antwort (Server #sym.arrow Client)*
  - Der Server verifiziert die Signatur und Frische der Anfrage.
  - Der Server erzeugt einen Zufallswert und ein ephemeres Schlüsselpaar.
  - Der Server signiert die Antwort (*ACK*) und sendet sie.
  - Der Server berechnet das geteilte Geheimnis und ist bereit, Nachrichten zu schicken.
+ *Handshake-Verifikation*
  - Der Client verifiziert die Signatur der Antwort.
  - Der Client berechnet das geteilte Geheimnis.
+ *Sitzungsaufbau*
  - Beide Partner leiten einen symmetrischen Cipher (*AES-256-GCM*) aus dem gemeinsamen Geheimnis ab.
  - Beide Partner speichern den Sitzungszustand.
  - Die Sitzung ist nun verschlüsselt.
+ *Nachrichtenaustausch*
  - *Senden*
    - Der Sender signiert und verschlüsselt die Nachricht.
    - Die Nachricht enthält die ID, Nonce und Signatur, sodass der Proxy die Nachricht auf Integrität und Authentizität prüfen kann, ohne sie zu entschlüsseln.
  - *Empfangen*
    - Der Empfänger prüft die Signatur und die Nachrichtenreihenfolge. Bei Fehlern wird die Nachricht abgelehnt.
    - Der Empfänger entschlüsselt die Nachricht und aktualisiert den Zähler.

== Sicherheitskonzept

Dieses Protokoll erreicht alle obengenannten Ziele (vgl. @ziele). Und zwar:

- *Vertraulichkeit*: Nach dem Schlüsselaustausch werden alle Nutzdaten mit einem gemeinsam abgeleiteten symmetrischen Sitzungsschlüssel (*AES-GCM*) verschlüsselt. Vor dem Abschluss des Handshakes werden nur Informationen übertragen, die nicht geheim sein müssen (z. B. öffentliche Schlüssel, Nonces, Zeitstempel).
- *Integrität*: Während des Handshakes werden Nachrichten mit dem eigenen geheimen Schlüssel signiert. Danach stellt *AES-GCM* sicher, dass jede nachträgliche Manipulation erkannt wird.
- *Authentizität*: Da die Signaturen überprüfbar sind, kann jede Partei sicherstellen, dass die empfangenen Nachrichten tatsächlich vom angegebenen Kommunikationspartner stammen. So wird ausgeschlossen, dass ein Angreifer gefälschte Nachrichten erfolgreich einschleusen kann.

= Umsetzung

Im vorherigen Kapitel wurden die einzelnen Komponenten des Systems beschrieben. In diesem Kapitel wird die App praktisch umgesetzt. Der Fokus liegt dabei nicht auf der vollständigen Darstellung des Codes, sondern auf den wichtigsten Strukturen und Designentscheidungen.

Die Implementierung folgt der in @komponenten definierten Aufteilung in die vier Module: *Protocol*, *Backend*, *Frontend-WASM*, *Frontend-Vue*. Den Anfang macht das _Protcol_-Modul, das die Nachrichtentypen und deren Datenstrukturen definiert. Danach folgt das Backend, das die Nachrichten weiterleitet, und das Frontend-WASM, in dem die Logik des Protokolls umgesetzt wird. Abschließend wird Frontend-Vue vorgestellt, das als Benutzeroberfläche dient.

Zunächst wird das _Protocol_-Modul, das die Nachrichtentypen und Datenstrukturen definiert, implementiert. Danach folgt das Backend und Frontend-WASM. Den Schluss macht Frontend-Vue, das die Benutzeroberfläche definiert.

== Protocol

Alle Nachrichten sollen in *Rust-Strukturen* definiert werden. Serialisierung und Deserialisierung erfolgen mit `serde`, einer Rust-Library, um Nachrichten als _JSON_ darzustellen. Jeder Chat hat eine eindeutige `id`, damit die Nachrichten eindeutig zugeordnet werden.

=== Handshake: SYN

Der Handshake beginnt mit einer Anfrage vom Client an den Server.

#figure(caption: [SYN Struktur])[
  ```rust
  pub struct SYN {
      pub id: u64,
      pub client_ver_key: ed25519_dalek::VerifyingKey,
      pub server_ver_key: ed25519_dalek::VerifyingKey,
      pub client_eph_pub_key: x25519_dalek::PublicKey,
      pub client_random: [u8; 32],
      pub timestamp: u64,
      pub signature: ed25519_dalek::Signature,
  }
  ```
]

*Enthaltene Daten:*

- *Client Verifying Key*: fester öffentlicher Schlüssel für Signaturen.
- *Server Verifying Key*: öffentlicher Schlüssel des Servers.
- *Client Ephemeral Public Key*: öffentlicher Schlüssel für Diffie-Hellman-Schüsselaustausch.
- *Client Random*: zufällige Bytes, schützen gegen Replay-Angriffe.
- *Timestamp*: zeitliche Gültigkeit, schützt gemeinsam mit Client-Random gegen Replay-Angriffe.
- *Signatur* über alle Felder, erstellt mit dem geheimen Schlüssel des Clients.

=== Handshake: ACK

Der Server antwortet mit einem Bestätigungspaket.

#figure(caption: [ACK Struktur])[
  ```rust
  pub struct ACK {
      pub id: u64,
      pub client_ver_key: ed25519_dalek::VerifyingKey,
      pub server_ver_key: ed25519_dalek::VerifyingKey,
      pub syn_digest: [u8; 32],
      pub server_eph_pub_key: x25519_dalek::PublicKey,
      pub server_random: [u8; 32],
      pub signature: ed25519_dalek::Signature,
  }
  ```
]

*Enthaltene Daten*:

- *Client und Server-Verifying-Keys*: Bestätigung der Identitäten.
- *Digest des SYN* stellt sicher, dass diese Antwort zum richtigen SYN gehört.
- *Server-Ephemeral-Public-Key*.
- *Server-Random*.
- *Signatur* über alle Felder, erstellt mit dem geheimen Schüssel des Servers.

=== Nachrichtenübertragung: MSG

Nach Abschluss des Handshakes wird der gemeinsame Cipher berechnet. Nun können Textnachrichten verschickt werden.

#figure(caption: [`EncryptedMessage` Struktur])[
  ```rust
  pub struct EncryptedMessage {
      pub id: u64,
      pub sender_ver_key: ed25519_dalek::VerifyingKey,
      pub receiver_ver_key: ed25519_dalek::VerifyingKey,
      pub message: EncryptedMessagePayload,
      pub nonce: GenericArray<u8, U12>,
      pub signature: ed25519_dalek::Signature,
  }
  ```
]

*Enthaltene Daten*:

- *Sender- und Empfänger-Keys* zur Authentifizierung mit dem Proxy.
- *Nonce*: Schützt AES-GCM vor Wiederholungen und bietet Nachweis für Integrität.
- *Ciphertext*: Verschlüsselte Nachricht
- *Signatur* über alle Felder

Dabei ist `EncryptedMessagePayload` eine Abstraktion über Bytes als Ciphertext (`Vec<u8>`). Werden diese entschlüsselt, erhält man `DecryptedMessagePayload`:

#figure(caption: [`DecryptedMessagePayload` Struktur])[
  ```rust
  pub struct DecryptedMessagePayload {
      pub id: u64,
      pub content: String,
  }
  ```
]

*Es enthält*:

- *ID*: Zähler der empfangenen Nachrichten. Schützt vor Replay-Angriffen und gibt die korrekte Reihenfolge der Nachrichten an.
- *Content*: Die Textnachricht selbst.

=== Fehlerbehandlung

Alle Strukturen haben `verify_signature()`-Methoden. Damit können Nachrichten sofort nach Integrität und Authentizität überprüft werden.

Fehler (falsche Signatur, ungültiges JSON, abgelaufene Pakete, usw.) werden explizit zurückgegeben. So, zum Beispiel, der Konstruktor von `EncryptedMessage`, der entweder sich selbst (`Self = EncryptedMessage`) konstruiert oder einen Fehler (`EncryptionError`) zurückgibt:

#figure(caption: [Fehlerbehandlung `EncryptedMessage` Beispiel])[
  ```rust
  impl EncryptedMessage {
    pub fn new(/* Felder */) -> Result<Self, EncryptionError> {/* Code */}

    // Andere Methoden...
  }
  
  pub enum EncryptionError {
      #[error("Failed to serialize the message")]
      SerializationFailed(#[from] serde_json::Error),
  
      #[error("AES encryption failed")]
      EncryptionFailed(String),
  }
  ```
]

=== Digest-Funktionen

Einige Strukturen haben eigene `digest()`-Methoden. Diese erzeugen einen Hashwert über alle wichtigen Felder, außer den Digest selbst.

=== Zusammenfassung des Ablaufs

+ *SYN*: Client startet Handshake.
+ *ACK*: Server bestätigt Handshake.
+ Beide berechnen denselben geheimen Schlüssel.
+ *MSG*: Ab hier nur noch verschlüsselte Kommunikation.

== Backend

Das Backend wurde ebenso in Rust geschrieben und übernimmt die Rolle eines Proxys. Es vermittelt die Nachrichten zwischen den Nutzern, hat aber selbst keine geheimen Schlüssel und kann somit die Nachrichten nicht entschlüsseln.

Der Proxy hat vor allem 4 Aufgaben:

+ Authentifizierung neuer Verbindungen.
+ Verwaltung aller verbundenen Clients.
+ Weiterleitung von Nachrichten.
+ Verifizierung der _Sender-Keys_.

=== Authentifizierung <auth>

Jeder Client muss sich beim Verbindungsaufbau mit dem *Verifying Key* und mit einer Signatur *ausweisen*. Dazu schickt der Proxy dem Client 32 zufällige Bytes, die der Client mit seinem Schlüssel signieren muss.

Der verwendete Datentyp sieht dabei so aus:

#figure(caption: [`AuthPacket` Struktur])[
  ```rust
  pub struct AuthPacket {
      pub ver_key: ed25519_dalek::VerifyingKey,
      pub signature: ed25519_dalek::Signature,
  }
  
  impl AuthPacket {
      pub fn verify(&self, random: &[u8; 32]) -> Result<(), ed25519_dalek::SignatureError> {
          self.ver_key.verify_strict(random, &self.signature)
      }
  }
  ```
]

Das Backend prüft schließlich, ob die Signatur korrekt ist. Ist sie inkorrekt, wird die Verbindung sofort abgebrochen.

=== Verwaltung der verbundenen Clients

Alle Clients werden in einer `HashMap` gespeichert. Als Schlüssel dienen die öffentlichen Schlüssel der Clients. Der Wert ist ein "Sender", über den Nachrichten an diesen Client geschickt werden können.

#figure(caption: [`PeerMap` Typdefinition])[
  ```rust
  type Tx = UnboundedSender<Message>;
  type PeerMap = Arc<Mutex<HashMap<ed25519_dalek::VerifyingKey, Tx>>>;
  ```
]

Dadurch wird sichergestellt, dass jede Nachricht an den richtigen Client gesendet wird.

=== Weiterleitung von Nachrichten

Wenn eine Nachricht am Proxy ankommt, wird geprüft:

+ Stimmt die Signatur?
+ Passt der Absender-Schlüssel zum angemeldeten Client?

Ist beides korrekt, wird der Empfänger in der `HashMap` gesucht und die Nachricht wird weitergeleitet.

#figure(caption: [Proxy Weiterleitung])[
  ```rust
  let recipient = match peers.iter().find(|(k, _)| *k == &receiver_ver_key) {
      Some(kv) => kv,
      None => {
          warn!("Recipient {:?} not connected", receiver_ver_key);
          return future::ok(());
      }
  };
  
  if let Err(e) = recipient.1.unbounded_send(msg.clone()) {
      error!("Failed to send message to {:?}: {:#}", receiver_ver_key, e);
  }
  ```
]

=== Start des Servers

Die `main`-Funktion sorgt dafür, dass der Proxy gestartet wird. Er läuft unter der Adresse `127.0.0.1:8080`. Jede neue Verbindung wird asynchron aufgenommen und an die Funktion `handle_connection` weitergegeben:

#figure(caption: [Proxy `main`-Funktion])[
  ```rust
  #[tokio::main]
  async fn main() -> Result<(), IoError> {
      tracing_subscriber::fmt::init();
  
      let bind_addr = env::args()
          .nth(1)
          .unwrap_or_else(|| "127.0.0.1:8080".to_string());
  
      let state = Arc::new(Mutex::new(HashMap::new()));
      let listener = TcpListener::bind(&bind_addr).await?;
      info!("Server listening on ws://{}", bind_addr);
  
      while let Ok((stream, peer_addr)) = listener.accept().await {
          let state = Arc::clone(&state);
          tokio::spawn(handle_connection(state, stream, peer_addr));
      }
  
      Ok(())
  }
  ```
]

Somit kann der Proxy mehrere Clients gleichzeitig bedienen, da jede Verbindung asynchron verarbeitet wird.

== Frontend

Das Frontend besteht aus zwei Teilen, die eng miteinander zusammenarbeiten:

- *WebAssembly (WASM)* beschäftigt sich mit den kryptographischen Operationen und mit der Paketlogik.
- *Vue* enthält die Benutzeroberfläche, hat eine Kopie des Zustands und stellt die Netzwerkverbindung mit dem Proxy über *WebSockets* @websocket_mdn her.

=== Interop zwischen Vue und WASM

WebAssembly ist eine Zielplattform, in welche Rust, C++ oder Go kompiliert werden können. Somit kann Rust-Code im Browser bei nahezu nativer Geschwindigkeit ausgeführt werden.

Interop zwischen JavaScript und WASM geschieht über Bindings, die Funktionen aus Rust zu JavaScript exportieren. Somit kann der Code sinnvoll zwischen verschiedenen Sprachen (hier JS und Rust) aufgeteilt werden.

Rust exportiert Funktionen mithilfe von `wasm_bindgen`. Diese werden zu WASM kompiliert und dann in Vue importiert.

*Beispielfunktion in Rust*

#figure(caption: [Rust `#[wasm_bindgen]` Beispiel])[
  ```rust
  #[wasm_bindgen]
  pub fn make_keypair() -> Result<js_sys::Array, JsValue> {
      // Beide Schlüssel generieren und in arr speichern  
      
      Ok(arr) // arr zurückgeben
  }
  ```
]

*Dann in JavaScript* (vereinfacht)

#figure(caption: [JavaScript WASM Import Beispiel])[
  ```js
  import { make_keypair } from "frontend-wasm"; // make_keypair wird importiert

  async generateKey() {
      const result = await make_keypair(); // Rust-Funktion wird ausgeführt
      const priv = Array.from(result[0]);
      const pub = Array.from(result[1]);
      this._storeKeypair(priv, pub); // Schlüssel wird gespeichert
  }
  ```
]

=== Zustandsaktualisierungen zwischen Vue und WASM

Damit Vue nicht jedes Mal den kompletten Zustand des Chats an WASM weitergeben muss, ist es von Vorteil, dass beide Teile des Frontends eine Kopie des Zustands haben. Wenn zum Beispiel eine Nachricht ankommt, wird `read_packet` (später in @paketlogik erklärt) gerufen. Der WASM-Teil liest die Nachricht, aktualisiert den eigenen Zustand und gibt Vue auch diese Aktualisierung zurück.

=== Zustand in WASM

In WASM wird der Zustand in einer Variable `STATE` der Struktur `MyState` als `RefCell` gespeichert. `RefCell` verhindert, dass der Zustand gleichzeitig von zwei Funktionen gelesen/verändert werden kann, und ist notwendig, damit der Code kompiliert werden kann.

#figure(caption: [Frontend-WASM Zustand])[
  ```rust
    thread_local! {
        static STATE: RefCell<MyState> = RefCell::new(MyState::default());
    }

    struct MyState {
        pub sign_key: Option<ed25519_dalek::SigningKey>,
        pub ver_key: Option<ed25519_dalek::VerifyingKey>,
        pub chats: HashMap<u64, Chat>,
        pub seen_nonces: HashSet<GenericArray<u8, U12>>,
    }
  ```
]

Der Zustand enthält

- Die Schlüssel
- Eine `HashMap` über Chat-IDs zu `Chat` Strukturen
- Ein `HashSet` über gesehene Nonces; schützt gegen Replay-Angriffe

Um auf den Zustand innerhalb der Funktionen zuzugreifen, muss am Anfang der Funktionen immer `STATE.with` gefolgt von einem `.borrow()` gerufen werden.

Zum Beispiel:

#figure(caption: [Zustand Zugriff Beispiel])[
  ```rust
  #[wasm_bindgen]
  pub fn proxy_connect(/* Felder */) -> Result<String, JsValue> {
      STATE.with(|state| {
          let state = state.borrow();
          let sign_key = state
              .sign_key
              .as_ref()
              .ok_or_else(|| JsValue::from_str("No signing key available"))?;
          let ver_key = state
              .ver_key
              .as_ref()
              .ok_or_else(|| JsValue::from_str("No verifying key available"))?;
  
          // Code
      })
  }
  ```
]

Wird `STATE` zu dieser Zeit verwendet, so wartet `STATE.with` bis die andere Funktion den `STATE` loslässt.

==== Chat Zustand

Ein Chat hat zwei mögliche Zustände: `Syn` und `Encrypted`.

Im Zustand `Syn` wurde der Chat bereits vom Client initiiert, das heißt, ein `SYN`-Paket wurde gesendet, jedoch noch kein `ACK`-Paket empfangen. Die Verbindung befindet sich somit im Aufbau.

Befindet sich der Chat im Zustand `Encrypted`, wurde der Handshake erfolgreich abgeschlossen, und es besteht eine vollständig etablierte und verschlüsselte Verbindung zwischen den Kommunikationspartnern.

=== Logik im Frontend (WASM) <paketlogik>

Die Aufgabe des Frontends unterscheidet sich von der des Proxys drastisch. Während der Proxy nur die Signaturen prüft und Nachrichten weiterleitet, ist das Frontend sowohl für die korrekte Implementierung des Handshakes als auch für die Verschlüsselung verantwortlich.

Im WASM-Teil des Frontends werden alle Funktionen geschrieben, die Pakete lesen/erzeugen und Schlüssel generieren -- also alles, was von Rust profitieren würde. Dazu gehören:

- `proxy_connect`: Signiert die zufälligen Bytes, um sich beim Proxy auszuweisen (siehe @auth).
- `make_keypair`: Generiert ein Schlüsselpaar (öffentlicher und geheimer Schlüssel).
- `load_sign_key`: Lädt einen bereits generierten Schlüssel.
- `init_chat`: Beginnt ein Chat mit einem anderen Nutzer.
- `read_packet`: Liest ein einkommendes Paket und entscheidet, was damit gemacht werden soll.
- `send_message`: Schickt eine Nachricht an einen Nutzer, mit dem schon eine Verbindung besteht.

==== `proxy_connect`

Wenn eine Verbindung zum Proxy hergestellt wird, sendet der Proxy dem Client 32 zufällige Bytes (vgl. @auth). Diese müssen mit dem geheimen Schlüssel vom Client signiert werden und gemeinsam mit dem öffentlichen Schlüssel an den Proxy zurückgesendet werden.

#figure(caption: [`proxy_connect` Implementation])[
  ```rust
  #[wasm_bindgen]
  pub fn proxy_connect(proxy_random: Vec<u8>) -> Result<String, JsValue> {
      // STATE ausborgen
    
      let mut sign_key = sign_key.clone();
      let signature = sign_key.sign(&proxy_random);

      let auth_packet = auth_packet::AuthPacket {
          ver_key: *ver_key,
          signature,
      };

      serde_json::to_string(&auth_packet)
          .map_err(|e| JsValue::from_str(&format!("Failed to serialize auth packet: {e}")))
  }
  ```
]

==== `make_keypair`

Hat ein Nutzer noch kein Schlüsselpaar, generiert diese Funktion ein zufälliges Paar.

==== `read_packet`

Sobald ein neues Paket ankommt, wird dessen Inhalt an die Funktion `read_packet` Funktion weitergeleitet. Sie dient als zentraler Dispatcher.

Abhängig vom Typ des Pakets werden interne Zustände aktualisiert, neue Nachrichten erzeugt und/oder Antwortpakete generiert.
Das Ergebnis wird in einem `ReadPacketReturnValue` kodiert.

Behebbare Fehler werden als spezielle Systemnachrichten gemeinsam mit anderen Nachrichten an das Frontend zurückgegeben.
Unbehebbare Fehler führen dazu, dass anstelle eines `ReadPacketReturnValue` ein `JsValue` mit einer Fehlermeldung als Text zurückgegeben wird.

#figure(caption: [`read_packet` Signatur])[
  ```rust
  struct ReadPacketReturnValue {
      message_updates: Vec<MessageUpdateToFrontend>,
      packet: Option<String>,
  }

  pub fn read_packet(packet: String) -> Result<String, JsValue>
  ```
]

Der empfangene `packet`-String wird zunächst deserialisiert.
Abhängig vom Ergebnis entsteht ein `SYN`, `ACK` oder `EncryptedMessage`-Paket.

Dieses wird anschließend an eine spezialisierte Handler-Funktion weitergeleitet:

- `handle_syn` (Initialisierung eines Chats)
- `handle_ack` (Bestätigung des Schlüsselaustauschs)
- `handle_encrypted_message` (ver-/entschlüsselte Kommunikation)

Alle Handler verwenden das gleiche Rückgabeformat wie `read_packet`, sodass die Verarbeitung einheitlich bleibt.
Nachfolgend ein Beispiel einer Handler-Signatur:

#figure(caption: [`handle_syn` Funktionsignatur Beispiel])[
  ```rust
  pub fn handle_syn(
      packet: Box<protocol::SYN>,
      state: &mut MyState,
      sign_key: &mut ed25519_dalek::SigningKey,
      ver_key: ed25519_dalek::VerifyingKey,
  ) -> Result<(Vec<MessageUpdateToFrontend>, Option<String>), JsValue>
  ```
]

Der erfolgreiche Rückgabetyp (`Vec<MessageUpdateToFrontend>, Option<String>`) enthält:

- *Neue Nachrichten*, die vom Frontend angezeigt werden sollen.
- *Optional ein Antwortpaket*, das an den Proxy versendet wird.

==== Verbindungsaufbau

===== Handshake-Initialisierung (`init_chat`) <init_chat>

Will ein Nutzer eine aktive Verbindung zu einem anderen herstellen, wird diese Funktion gerufen. Sie nimmt als Argument den öffentlichen Schlüssel der anderen Person und gibt ein Paket zurück, das an den Proxy geschickt werden muss. Dies ist der erste Schritt bei der Herstellung einer sicheren Verbindung.

So läuft sie ab:

+ Ein `client_random` (32 zufällige Bytes) werden generiert.
+ Eine zufällige Chat-ID -- 64-bit ganze positive Zahl (`u64`) -- wird erstellt.
+ Ein ephemeres Schlüsselpaar wird generiert.
+ Es wird der jetzige Zeitstempel (Millisekunden seit 1970) genommen.
+ Nun kann das `SYM` Paket erstellt werden.

===== Handshake-Verifikation und Handshake-Antwort (`handle_syn`)

Initiiert eine andere Person -- der Client -- ein Chat mit `init_chat` (@init_chat), welche dabei ein `SYN`-Paket absendet, wird bei dem Server die `handle_syn` Funktion mit dem Inhalt des Pakets gerufen.

Bevor ein Handshake bestätigt werden kann (siehe @protokollentwurf), werden die Felder des `SYN`-Pakets ausführlich validiert.

Dabei können behebbare Fehler auftreten, u. a.:

- Ein Chat mit derselben Chat-ID existiert bereits.
- Die Signatur des Pakets ist ungültig.
- Der öffentliche Schlüssel stimmt nicht mit dem erwarteten Schlüssel überein.
- Das Paket ist älter als 5 Sekunden.

Wenn keine dieser Fehlerbedingungen vorliegt, wird gemäß @protokollentwurf ein `ACK`-Paket erzeugt und zurückgegeben.

Nach dem Empfang eines gültigen `SYN` generiert die Server-Seite ihr ephemeres Schlüsselpaar und kann das gemeinsame Sitzungsschlüsselmaterial sofort ableiten. Damit ist der Handshake aus Sicht des Servers bereits abgeschlossen und der Server ist *ab diesem Zeitpunkt vollständig kryptografisch abgesichert*.

Die Verbindung ist allerdings erst dann wechselseitig abgesichert, sobald der Client das `ACK` empfangen, überprüft und ebenfalls den gemeinsamen Sitzungsschlüssel berechnet hat. Erst anschließend können beide Seiten verschlüsselte Nachrichten über `MSG`-Pakete austauschen.

Durch die ausschließliche Verwendung ephemerer erzeugter Schlüsselmateralien (X25519) erreicht das Protokoll Forward Secrecy: Kompromittierte Langzeitschlüssel führen *nicht* zur Entschlüsselung bereits übertragener Nachrichten.

===== Handshake-Verifikation (`handle_ack`)

Auf der Client-Seite stellt `handle_ack` den Abschluss des Handshakes dar.
Sie wird aufgerufen, sobald der Client ein `ACK`-Paket vom Gesprächspartner erhält.

Zuerst werden die beim Versand des ursprünglichen SYN hinterlegten Daten aus dem lokalen Zustand rekonstruiert. Anschließend wird überprüft, ob das Paket inhaltlich konsistent ist. Fehlerhafte oder widersprüchliche `ACK`-Pakete werden als Systemmeldungen an das Frontend gemeldet, ohne dass weitere Aktionen ausgeführt werden.

Die Validierung umfasst dabei folgende Aspekte:

- Die Signatur des Pakets muss gültig sein.
- Der angegebene Empfänger-Schlüssel muss dem erwarteten öffentlichen Schlüssel entsprechen.
- Die im Paket enthaltene Prüfsumme des ursprünglichen `SYN` (Digest) darf nicht abweichen.
- Der im Handshake ausgehandelte Server-Schlüssel muss mit dem ursprünglich empfangenen übereinstimmen.

Sind alle Prüfungen erfolgreich, ist sichergestellt, dass:

- Keine Manipulation durch Dritte erfolgt ist.
- Beide Seiten denselben Handshake-Partner bestätigen.
- Das `ACK` tatsächlich auf das zuvor gesendete `SYN` referenziert.

Erst dann wird aus dem eigenen ephemeren Private Key und dem Public Key der Gegenseite ein gemeinsames Geheimnis berechnet. Daraus wird ein AES-256-GCM-Cipher für die weitere, verschlüsselte Kommunikation abgeleitet.

Zum Schluss wird der Chat-Status in `Chat::Encrypted` überführt, womit nun auch der Client die verschlüsselte Kommunikation aufnehmen kann. Der Handshake ist damit beidseitig abgeschlossen.

==== Nachrichtenaustausch

Nach dem Abschluss des Handshakes befinden sich beide Parteien in einem synchronisierten, verschlüsselte Zustand (`Chat::Encrypted`).

Ab diesem Zeitpunkt können Nachrichten in beide Richtungen verschlüsselt übertragen werden.

Das Frontend unterscheidet dabei zwischen eingehenden (`handle_encrypted_message`) und ausgehenden (`send_message`) Nachrichten.

Beide Funktionen greifen auf denselben AES-GCM-Cipher und denselben Sequenzzähler zu.

===== Empfangen (`handle_encrypted_message`)

Immer wenn ein verschlüsseltes Paket ankommt, ruft `read_packet` intern `handle_encrypted_message` auf. Diese Funktion prüft und entschlüsselt das Paket und gibt die resultierende Nachricht an das Frontend weiter.

Zuerst wird geprüft, ob der Chat überhaupt existiert und der Zustand `Encrypted` ist.

#figure(caption: [`handle_encrypted_message` Prüfung Beispiel])[
  ```rust
  if let Some(chat) = state.chats.get_mut(&packet.id) {
      if let Chat::Encrypted { cipher, other_ver_key, .. } = chat {
          // Nachricht entschlüsseln
      } else {
          // Chat existiert, ist aber nicht verschlüsselt
      }
  } else {
      // Chat existiert nicht
  }
  ```
]

Danach folgen Integritätsprüfungen:

- *Sequenz-ID*: verhindert doppelte oder übersprungene Nachrichten.
- *Absender-Schlüssel*: stellt sicher, dass das Paket tatsächlich vom Kommunikationspartner stammt.
- *AES-GCM-Entschlüsselung*: authentifiziert und entschlüsselt den Inhalt.
- *Nonce-Prüfung*: überprüft, ob der verwendete Nonce bereits früher empfangen wurde.

Der relevante Abschnitt:

#figure(caption: [Nachrichtenentschlüsselung])[
  ```rust
  let message = match packet.message.decrypt(cipher, packet.nonce) {
      Ok(m) => m,
      Err(e) => {
          message_updates.push(MessageUpdateToFrontend {
              chat_id: packet.id.to_string(),
              message: Message::System(format!(
                  "decryption failed: {}", e
              )),
          });
          return Ok((message_updates, None));
      }
  };
  ```
]

Nach der Entschlüsselung wird die Nachricht intern gespeichert und an das Frontend weitergegeben:

#figure(caption: [Einfügen und Weiterleiten einer empfangenen Nachricht])[
  ```rust
  messages.push(Message::ToSelf(message.clone()));
  message_updates.push(MessageUpdateToFrontend {
      chat_id: packet.id.to_string(),
      message: Message::ToSelf(message),
  });
  ```
]

===== Senden (`send_message`)

Um eine Nachricht zu senden, ruft das Frontend die Funktion `send_message`.

Diese baut aus dem Text eine verschlüsselte Paketstruktur (`EncryptedMessage`) und gibt diese als serialisiertes JSON zurück, das dann an den Proxy gesendet wird.

Als Erstes wird der Nachrichten-Zähler erhöht und in der Payload gespeichert:

#figure(caption: [Zähler Erhöhung])[
  ```rust
  let decrypted_payload = protocol::DecryptedMessagePayload {
      id: *prev_id_self + 1,
      content: message,
  };
  *prev_id_self += 1;
  ```
]

Danach wird der Text mit AES-GCM verschlüsselt und signiert:

#figure(caption: [AES-GCM-Verschlüsselung])[
  ```rust
  let encrypted_packet = protocol::EncryptedMessage::new(
      chat_id,
      ver_key,
      *other_ver_key,
      &decrypted_payload,
      cipher,
      &mut sign_key.clone(),
  )?;
  ```
]

Abschließend wird das Paket serialisiert:

#figure(caption: [Paket-Serialisierung])[
  ```rust
  let packet_json = serde_json::to_string(&packet)
      .map_err(|_| JsValue::from_str("failed to serialize packet"))?;
  ```
]

Diese JSON-Darstellung wird an den Proxy übergeben und dann an den Empfänger weitergeleitet.

===== Ablauf im Überblick

#figure(caption: [Senden Überbilck])[
  #diagram(
    spacing: (18mm, 10mm),
    node-stroke: teal,
    node-fill: teal.lighten(90%),
    node((0,0), [*`send_message`*], name: <1>),
    node((0,1), [*AES-GCM-Verschlüsselung*], name: <2>),
    node((0,2), [*`EncryptedMessage`*], name: <3>),
    node((0,3), [*Proxy*], name: <4>),
    node((0,4), [*`read_packet`*], name: <5>),
    node((0,5), [*`handle_encrypted_message`*], name: <6>),
    node((0,6), [*Entschlüsselung*], name: <7>),
    node((0,7), [*Anzeige im Frontend*], name: <8>),
    node(enclose: (<1>, <2>, <3>), stroke: green, fill: green.lighten(90%), name: <g1>),
    node(enclose: (<5>, <6>, <7>, <8>), stroke: green, fill: green.lighten(90%), name: <g2>),
    node((1, 1), [*Sender*], name: <u1>, stroke: none, fill: none),
    node((1, 5.5), [*Empfänger*], name: <u2>, stroke: none, fill: none),
    edge(<1>, "-|>", <2>),
    edge(<2>, "-|>", <3>),
    edge(<3>, "-|>", <4>),
    edge(<4>, "-|>", <5>),
    edge(<5>, "-|>", <6>),
    edge(<6>, "-|>", <7>),
    edge(<7>, "-|>", <8>),
    edge(<g1>, "-", <u1>),
    edge(<g2>, "-", <u2>),
  )
]

Damit ist der Ende-zu-Ende-verschlüsselte Nachrichtenaustausch vollständig implementiert: Jede Nachricht wird authentifiziert, nummeriert und verschlüsselt übertragen, womit die zentralen Sicherheitsziele von TLS erreicht werden.

=== Frontend in Vue mit Vite

Das Frontend bildet die Benutzerschnittstelle des Messengers und ist vollständig in *Vue 3* umgesetzt. Es ermöglicht die Interaktion mit dem Benutzer, die Anzeige von Chats und Nachrichten sowie die Steuerung kryptografischer Funktionen über eine WebAssembly-Schnittstelle.
Das Build-System *Vite* wurde gewählt, um eine schnelle Entwicklungsumgebung mit integriertem Hot-Reloading, modularem Aufbau und optimierter Bereitstellung für Browser bereitzustellen.
Durch die modulare Architektur und das reaktive Datenmodell von Vue kann die Benutzeroberfläche effizient auf Änderungen des internen Zustands reagieren, ohne dass manuelle DOM-Manipulationen erforderlich sind.

==== Projektstruktur

Der Code des Frontends ist klar strukturiert. Der Einstiegspunkt `main.js` initialisiert die Anwendung und bindet die Hauptkomponente `App.vue` in das DOM ein. Diese Komponente ist ein Container für `ChatApp.vue`, welche die Benutzeroberfläche und Interaktionslogik lädt.

Die Datei `store.js` verwaltet den Anwendungszustand, baut die WebSocket-Verbindung auf und ist die Schnittstelle zu den WASM-Funktionen. `vite.config.js` enthält die Konfiguration des Build-Prozesses, während `style.css` die Stile der Seite bereitstellt.

Der Projektbaum ist wie folgt aufgebaut:

#pseudocode-list[
  + frontend-vue
    + Dockerfile
    + index.html
    + LICENSE
    + package.json
    + package-lock.json
    + README.md
    + src
      + App.vue
      + assets
        + vue.svg
      + components
        + ChatApp.vue
      + main.js
      + store.js
      + style.css
    + vite.config.js
]

==== Reaktiver Zustand und Datenfluss

Das Frontend nutzt die reaktiven Möglichkeiten von Vue 3, um Änderungen im Zustand automatisch in der Benutzeroberfläche zu reflektieren. Hier kommen die Funktionen `reactive`, `ref` und `computed` auf der Composition-API zum Einsatz.

Der zentrale Zustand wird in `store.js` mit `reactive()` definiert. Darin werden alle aktiven Chats, die aktuelle Chat-ID, der Authentifizierungsstatus, der eigene Schlüssel und der Status der WebSocket-Verbindung verwaltet.

#figure(caption: [`store.js` Zustand])[
  ```js
  const state = reactive({
    chats: [], // [{ id, name, messages: [] }]
    currentChatId: null,
    signKey: null,
    verKey: null,
    websocket: null,
    isKeyLoaded: false,
    isAuthenticated: false,
  });
  
  export default {
    state,

    // Funktionen
  }
  ```
]

Die Datenflüsse gehen in beide Richtungen:

+ Eine Benutzeraktion im Interface (z. B. das Senden einer Nachricht) ruft eine Methode im Store auf.
+ Der Store verarbeitet die Eingabe, verschlüsselt die Nachricht über die Rust-WASM-Bibliothek und sendet sie über den WebSocket an das Backend.
+ Sobald eine Antwort oder neue Nachricht eintrifft, wird diese über `read_packet()` entschlüsselt und in den reaktiven Zustand übernommen.
+ Vue aktualisiert die Oberfläche automatisch entsprechend dem neuen Zustand.

Auf diese Weise bleibt die Anwendung einfach nachvollziehbar, modular und robust gegenüber Nebenwirkungen.

==== Aufbau und Verwaltung der WebSocket-Verbindung

Die Kommunikation mit dem Rust-Backend erfolgt über eine persistente WebSocket-Verbindung, die in `store.js` initialisiert wird. Sobald der Benutzer eine Schlüsseldatei importiert oder ein neues Schlüsselpaar generiert, ruft der Store die Funktionen `_connectWebSocket()` auf.  Diese stellt eine Verbindung zum Proxy-Server (während des Entwicklungsprozesses unter `ws://127.0.0.1:8080`) her und verwaltet eingehenden sowie ausgehenden Pakete.

Der Ablauf gliedert sich in mehrere Phasen:

+ *Verbindungsaufbau*: Beim Öffnen der Verbindung (`ws.onopen`) wird der Status auf "verbunden" gesetzt.
+ *Authentifizierung*: Die erste empfangene Nachricht wird an die Funktion `proxy_connect()` in der WebAssembly-Bibliothek weitergegeben. Diese überprüft den öffentlichen Schlüssel des Clients und leitet den Handshake-Prozess ein.
+ *Nachrichtenübertragung*: Eingehende Datenpakete werden von `read_packet()` analysiert und entschlüsselt. Anschließend werden sie als Ereignisse in den Zustand übernommen.
+ *Fehlerbehandlung*: Bei Unterbrechungen oder Fehlern (`ws.onerror`, `ws.onclose`) wird der Zustand zurückgesetzt, und der Benutzer kann manuell eine neue Verbindung herstellen.

Durch die klare Trennung von Verbindung, Authentifizierung und Nachrichtenverarbeitung bleibt die WebSocket-Logik übersichtlich und effizient.

==== Benutzeroberfläche und Komponentenstruktur

Die Oberfläche ist in zwei Bereiche geteilt: eine *Sidebar* und den *Chatbereich*.

Die Sidebar zeigt alle verfügbaren Chats an und enthält Bedienelemente für das Erstellen neuer Chats, den Import von Schlüsseln und die Anzeige der eigenen Verifikationsinformationen.Der Hauptbereich stellt die Nachrichtenliste des aktuell ausgewählten Chats dar und enthält ein Eingabefeld zum Verfassen von Nachrichten.

Alle sichtbaren Elemente werden in `ChatApp.vue` definiert. Diese Komponente verwendet die `<script setup>`-Syntax, wodurch die reaktive Logik direkt innerhalb des Komponenten-Scopes beschrieben wird. Über `v-model` sind Eingabefelder an den Zustand des Stores gebunden, während Klick-Ereignisse Methoden wie `sendMessage()` oder `startChat()` auslösen.

Das Layout nutzt Flexbox-Strukturen und CSS-Variablen, um sich an unterschiedliche Bildschirmgrößen anzupassen. Für mobile Geräte kann die Sidebar über eine Burger-Schaltfläche ein- und ausgeblendet werden.

#figure(
  image("lustiger_chat.png"),
  caption: [Screenshot der Chat-App]
)

==== Fazit

Das Frontend zeigt, wie sich moderne Webtechnologien mit sicherer Systemprogrammierung kombinieren lassen. Vite ermöglicht eine schnelle und modulare Entwicklungsumgebung, während Vue 3 durch sein reaktives Datenmodell eine stabile und intuitive Benutzeroberfläche bereitstellt.

== Docker

Für das Hosting des Frontends sowie des Backends wurde Docker verwendet. Damit kann die Anwendung isoliert und reproduzierbar ausgeführt werden. Es werden zwei Hauptkomponenten betrachtet: das Frontend, bestehend aus Vue, WASM und dem gemeinsamen Protokoll, und das Backend gemeinsam mit dem Protokoll. Jede Komponente wird in einem eigenen Container betrieben, wodurch die Abhängigkeiten und Build-Prozesse voneinander getrennt sind.

=== Backend

Das Backend ist eine Rust-Anwendung, die über Port 8080 erreichbar ist. Der Dockerfile für das Backend nutzt einen Multi-Stage-Build, um zunächst die Anwendung zu kompilieren und anschließend nur die fertige Binärdatei in das finale Image zu kopieren:

#figure(caption: [Backend Dockerfile])[
  ```dockerfile
  FROM rust:latest AS build
  WORKDIR /app
  COPY backend ./backend
  COPY protocol ./protocol
  WORKDIR /app/backend
  RUN cargo build --release
  
  FROM debian:bookworm-slim
  WORKDIR /app
  COPY --from=build /app/backend/target/release/backend /app/backend
  EXPOSE 8080
  CMD ["./backend"]
  ```
]

=== Frontend & WebAssembly

Das Frontend verwendet Vue mit Vite. Zusätzlich wird das WASM-Modul vor dem Vue-Build erstellt und in die Projektstruktur eingebunden. Auch hier wird ein Multi-Stage-Build verwendet:

#figure(caption: [Frontend Dockerfile])[
  ```dockerfile
  # WASM-Build
  FROM rustlang/rust:latest AS wasm-build
  WORKDIR /app
  RUN cargo install wasm-pack
  COPY protocol ./protocol
  COPY frontend-wasm ./frontend-wasm
  WORKDIR /app/frontend-wasm
  RUN wasm-pack build --target web --release
  
  # Vue-Build
  FROM node:22 AS frontend-build
  WORKDIR /app
  COPY frontend-vue ./frontend-vue
  COPY --from=wasm-build /app/frontend-wasm/pkg ./frontend-wasm/pkg
  WORKDIR /app/frontend-vue
  RUN npm ci
  RUN npm run build
  
  # Nginx-Server
  FROM nginx:stable-alpine
  WORKDIR /usr/share/nginx/html
  COPY --from=frontend-build /app/frontend-vue/dist ./
  EXPOSE 80
  CMD ["nginx", "-g", "daemon off;"]
  ```
]

=== Docker Compose

Zur Koordination aller Container wird *docker-compose* verwendet. Dadurch können Backend und Frontend gleichzeitig gestartet werden:

#figure(caption: [`docker-compose.yml`])[
  ```yaml
  services:
    backend:
      build: ./backend
      ports:
        - "8080:8080"
    frontend:
      build: ./frontend-vue
      ports:
        - "80:80"
  ```
]

Durch Docker wird sichergestellt, dass die Anwendung auf jedem System gleich läuft, die Build-Abhängigkeiten korrekt ausgeführt werden und der Start einfach über `docker compose up` erfolgt.

== Paketablauf bei einer neuen Verbindung (Beispiel)

Folgend ist ein Beispiel, das das Design des Protokolls abschließend veranschaulicht.

Es zeigt den vollständigen Nachrichtenfluss zwischen zwei Clients über den Proxy und veranschaulicht, wie die verschlüsselte Verbindung konkret erreicht wird.

Nach der Schlüsselerzeugung und der Authentifizierung beim Proxy erfolgt der eigentliche Aufbau einer neuen Verbindung zwischen zwei Kommunikationspartnern.

Folgend sind alle relevanten Pakete in der richtigen Reihenfolge dargestellt.

Jedes Paket wird tabellarisch beschrieben, wobei die linke Spalte die Feldnamen und die rechte Spalte die jeweiligen Eigenschaften oder Inhalte enthält.

=== Empfang von Proxy

Dieses Paket signalisiert, dass der Proxy bereit ist, und dient in erster Linie als Übertrag des öffentlichen Schlüssels bzw. als Initialisierungssignal.

#set table(columns: (auto, auto))

#figure(caption: [Empfang von Proxy])[
  #table(
    table.header([Feld], [Beschreibung]),
    `[32 Bytes]`,
    [`server_random`, zufälliger 32-Byte-Wert. Wird vom Client für die spätere Signaturprüfung genutzt. Nicht wiederverwendet.]
  )
]

=== Authentifizierungsanfrage an den Proxy

Der Benutzer authentifiziert sich, indem er die zufälligen 32 Bytes signiert und den eigenen öffentlichen Schlüssel mitsendet.

#figure(caption: [Authentifizierungsanfrage an den Proxy])[
  #table(
    table.header([Feld], [Beschreibung]),
    `ver_key`,
    [Öffentlicher Verifikationsschlüssel (32 Bytes), der den Client eindeutig identifiziert. Wird auch in späteren Paketen verwendet.],
    `signature`,
    [64-Byte-Signatur über den `server_random` vom Proxy. Stellt sicher, dass der Client den zugehörigen privaten Schlüssel besitzt. Zufällig in ihrer Bitstruktur, aber deterministisch aus `server_random` und Schlüssel berechnet.]
  )
]

=== SYN

Das SYN-Paket leitet den eigentlichen Verbindungsaufbau ein (analog zum TLS-ClientHello). Es enthält sämtliche Parameter, die für die Aushandlung der Sitzungsschlüssel notwendig sind.

#figure(caption: [SYN])[
  #table(
    table.header([Feld], [Beschreibung]),
    `id`,
    [64-Bit-Zufallszahl, die die Verbindung eindeutig identifiziert. Wird in allen folgenden Paketen wiederverwendet.],
    `client_ver_key`,
    [Öffentlicher Verifikationsschlüssel des Clients (32 Bytes). Identisch mit dem Wert aus der Authentifizierung.],
    `server_ver_key`,
    [Erwarteter öffentlicher Verifikationsschlüssel des Servers (32 Bytes). Dient der Zielbestimmung.],
    `client_eph_pub_key`,
    [Ephemerer öffentlicher Schlüssel (32 Bytes). Nur für diese Verbindung gültig; ermöglicht Forward Secrecy.],
    `client_random`,
    [32 zufällige Bytes, analog zum ClientRandom in TLS; dient zur Erzeugung des Sitzungsschlüssels.],
    `timestamp`,
    [UNIX-Zeit in Millisekunden; schützt gegen Replay-Angriffe.],
    `signature`,
    [64-Byte-Signatur über den gesamten Paketinhalt. Authentifiziert den Ursprung und schützt die Integrität.]
  )
]

=== ACK

Das ACK-Paket ist die Antwort des Servers auf das SYN. Es bestätigt die erhaltenen Parameter und liefert eigene Schlüsselanteile.

#figure(caption: [ACK])[
  #table(
    table.header([Feld], [Beschreibung]),
    `id`,
    [Gleiche Sitzungs-ID wie im SYN (64 Bit). Verknüpft beide Pakete eindeutig.],
    `client_ver_key`,
    [Öffentlicher Schlüssel des Clients; wiederholt zur Bindung der Nachricht an denselben Kommunikationspartner.],
    `server_ver_key`,
    [Öffentlicher Schlüssel des Servers. Gleicher Wert wie im SYN angegeben.],
    `syn_digest`,
    [32-Byte-Hashwert des empfangenen SYN-Pakets. Dient der Integritätsprüfung.],
    `server_eph_pub_key`,
    [Ephemerer öffentlicher Schlüssel des Servers (32 Bytes).],
    `server_random`,
    [32 zufällige Bytes, analog zum ServerRandom in TLS. Fließt ebenfalls in die Schlüsselableitung ein.],
    `signature`,
    [64-Byte-Signatur über das ACK-Paket. Authentifiziert den Server.]
  )
]

=== EncryptedMessage

Nach erfolgreichem Handshake verfügen beide Partner über denselben Sitzungsschlüssel.

Ab diesem Punkt werden Nachrichten symmetrisch verschlüsselt übertragen.

#figure(caption: [EncryptedMessage])[
  #table(
    table.header([Feld], [Beschreibung]),
    `id`,
    [Gleiches Sitzungs-ID-Feld wie zuvor (64 Bit). Identifiziert den Nachrichtenkontext.],
    `sender_ver_key`,
    [Öffentlicher Schlüssel des Absenders (32 Bytes). Dient der Zuordnung im Mehrbenutzersystem.],
    `receiver_ver_key`,
    [Öffentlicher Schlüssel des Empfängers (32 Bytes). Entspricht dem Ziel der verschlüsselten Nachricht.],
    `message`,
    [Verschlüsselter Nachrichteninhalt (z. B. 42 Bytes). Länge variabel, abhängig vom Klartext.],
    `nonce`,
    [12-Byte-Zufallswert pro Nachricht. Gewährleistet Einmaligkeit im AES-GCM-Modus.],
    `signature`,
    [64-Byte-Signatur über alle unverschlüsselten Felder. Wird nur vom Proxy kontrolliert]
  )
]

= Test und Validierung mit Burp Suite

In diesem Kapitel werden die Sicherheitsmaßnahmen der App verifiziert. Die Testumgebung und das Testverfahren werden beschrieben, mit denen die Sicherheit des Protokolls nachvollziehbar geprüft werden kann.

== Testumgebung und Voraussetzungen

Die Tests wurden mit der *freien Edition von Burp Suite* durchgeführt. Es wurde der in Burp integrierte Browser verwendet. Dadurch erfolgt der Datenverkehr *nur über den Burp-Proxy*, der auf Port 8081 gestartet wird (Standard-Port 8080 wird bereits für die WebSocket-Kommunikation verwendet).

Es ist wichtig zu betonen, dass *nur ein Testnutzer* über den *Burp‑Browser* angebunden ist; *Backend und der zweite Client* laufen in der Testumgebung *unverändert* und werden nicht durch Burp geleitet. So wird nur ein Nutzer getestet. Der Server und der andere Nutzer bleiben unbeeinträchtigt.

Das getestete Protokoll ist in *JSON* serialisiert. Dies erleichtert die Analyse mit Burp-Werkzeugen (Inspector, Repeater, Decoder), da auf Payloads direkt zugegriffen werden kann.

== Aufbau des Tests

Nachdem der Normalablauf dokumentiert wurde, wird für jeden Test eine neue Verbindung hergestellt. Einzelne Pakete werden abgefangen, im *Burp-Repeater* modifiziert und anschließend erneut gesendet. Auf diese Weise können Sicherheitslücken gezielt gefunden werden. Die nachfolgende Reaktion von Client, Server und Proxy lässt klar wissen, ob der Angriff erfolgreich durchgeführt wurde.

== Normalablauf und Initialisierung

Zu Beginn der Tests werden Backend und Frontend lokal gestartet. Dazu wird im Stammverzeichnis der Befehl `docker compose up -d` ausgeführt; nach erfolgreichem Start ist die Anwendung über `http://localhost:80` bzw. `http://127.0.0.1` erreichbar. Dieser Schritt stellt die Baseline-Umgebung her, in der Server- und Proxy-Instanzen in der erwarteten, unveränderten Konfiguration laufen.

=== Simulierte unbeeinträchtigte Nutzersitzung

Zur Simulation eines unbeeinträchtigten Kommunikationspartners wird die Weboberfläche der Applikation in einem gewöhnlichen Browser (z. B. Mozilla Firefox) geöffnet. Dieser Nutzer agiert ohne Einbindung in Burp.

=== Start von Burp Suite und Aufnahme des Proxy-Verkehrs

Anschließend wird Burp Suite gestartet. Im Bereich "Proxy" des Programms wird der integrierte Burp-Browser geöffnet und der Intercept-Modus aktiviert, sodass der gesamte vom Burp-Browser initiierte Verkehr über den Burp-Proxy auf Port 8081 geleitet und dort abgefangen werden kann. Die in Burp aufgezeichneten Verkehrseinträge werden in der *History* protokolliert und können in weiteren Untersuchungen in den Werkzeugen Repeater verwendet werden.

#figure(caption: [Burp: Intercept-Ansicht und Burp-Browser],
  image("Burp Screenshots/two_empty.png"),
)

#figure(caption: [HTTP History],
  image("Burp Screenshots/http_logs.png"),
)

=== Initialisierung: Schlüsselgenerierung und Proxy-Authentifizierung

Der Client erzeugt sein Schlüsselpaar und authentifiziert sich gegenüber dem Proxy. Die für die Authentifizierung relevanten Nachrichten (z. B. der initiale Challenge-Austausch und die vom Client gesendete Signatur samt öffentlichem Verifikationsschlüssel) sind in Burp sichtbar. Bei Verwendung des Burp-Browsers erscheinen diese Nachrichten in der entsprechenden History-Ansicht; bei WebSocket-basierten Handshakes sind die Einträge im WebSockets-History-Tab sichtbar.

#figure(caption: [Proxy Challenge (Anfrage)],
  image("Burp Screenshots/challange.png"),
)

#figure(caption: [Proxy Challenge (Antwort)],
  image("Burp Screenshots/challange_response.png"),
)

=== Verbindungsaufbau zwischen Clients (SYN / ACK)

Bei Initiierung einer Verbindung zu einem anderen Nutzer wird der SYN-Handshake erzeugt; die anschließende Server-Antwort erfolgt in Form eines ACK-Pakets. Beide Pakettypen (SYN und ACK), inklusive ihrer JSON-serialisierten Felder (z. B. `id`, `client_eph_pub_key`, `syn_digest`, `server_eph_pub_key`), können gesehen werden.

#figure(caption: [SYN-Paket],
  image("Burp Screenshots/syn.png"),
)

#figure(caption: [ACK-Paket],
  image("Burp Screenshots/ack.png"),
)

=== Laufende verschlüsselte Nachrichten (EncryptedMessage)

Nach erfolgreichem Abschluss des Handshakes werden die Nachrichten im `EncryptedMessage`-Format ausgetauscht. Diese Einträge lassen sich in der Burp-History als JSON-Objekte identifizieren; die verschlüsselte Nachricht (`message`), das nonce-Feld und die Metadaten (`sender_ver_key`, `receiver_ver_key`, `id`) sind dort sichtbar und können zwischen Nutzer und Proxy manipuliert werden.

#figure(caption: [EncryptedMessage (MSG-Paket)],
  image("Burp Screenshots/msg.png"),
)

== SYN im Namen eines fremden Clients senden

In diesem Test wurde geprüft, ob nach erfolgreicher Authentifizierung eines Clients ein Angreifer (hier simuliert durch den Burp-Browser) ein SYN-Paket im Namen eines anderen, nicht registrierten Clients verschicken kann. Technisch gesagt, ob sich die Sitzungs-/Verbindungslogik durch ein gefälschtes `client_ver_key` austricksen lässt.

Dazu wurde zunächst eine gültige Sitzung eines registrierten Clients aufgebaut und die zugehörigen Handshake-Pakete (inklusive der Authentifizierungsnachricht gegenüber dem Proxy) in Burp aufgezeichnet. Anschließend wurde ein im WebSocket-Verlauf erfasstes SYN-Paket in den Repeater übernommen und dort das Feld `client_ver_key` durch den öffentlichen Schlüssel eines anderen Clients ersetzt, während der restliche JSON-Payload unverändert blieb. Dieses manipulierte Paket wurde erneut an den Proxy gesendet, um zu prüfen, ob die gefälschte Identität akzeptiert wird.

Der Proxy wies das Paket jedoch still ab; es erfolgte keine Bestätigung, kein ACK und keine Weiterleitung zum Ziel-Peer. Daraus lässt sich schließen, dass der Proxy nach der Authentifizierung eine feste Bindung zu nachfolgenden SYN-Anfragen herstellt und gefälschte `client_ver_key`-Felder nicht akzeptiert.

#figure(caption: [Repeater: Wiederholung eines SYN-Pakets mit verändertem `client_ver_key`],
  image("Burp Screenshots/repeater_syn.png"),
)

== Rolle des Proxys und Anpassung für die Tests

Der Proxy übernimmt einen großen Teil der Sicherheitsprüfung im System, indem er die Signaturen aller eingehenden Pakete verifiziert und dadurch Integrität und Authentizität sicherstellt. Manipulierte Nachrichten werden dadurch bereits abgefangen, bevor sie den Empfänger erreichen.

Für die Protokollanalyse ist diese Schutzwirkung jedoch hinderlich, da so nicht sichtbar wird, wie die Endpunkte selbst auf veränderte oder fehlerhafte Pakete reagieren würden. Es kann jedoch passieren, dass der Proxy selbst kompromittiert wird. Um das Protokoll unabhängig von der Proxy-Sicherheit bewerten zu können, wurde die Signaturprüfung im Proxy für alle weiteren Tests deaktiviert. Dadurch konnten auch Angriffe simuliert werden, die ansonsten bereits frühzeitig blockiert worden wären.

== Replay-Angriff auf SYN-Pakete

Hier wurde untersucht, ob Handshake-Nachrichten mit veralteten Zeitstempeln akzeptiert werden. Ein gültiges SYN-Paket wurde abgefangen, einige Sekunden verzögert und erst dann weitergeleitet.

Der Server verwarf den Verbindungsaufbau mit der Meldung:
*"tried to start chat … but timestamp too old"*.
Damit zeigt sich, dass der Zeitstempelmechanismus zuverlässig gegen verspätete Handshake-Pakete schützt.

#figure(
caption: [Repeater Tab],
image("Burp Screenshots/repeater.png"),
)

== Replay-Angriff auf verschlüsselte Nachrichten

In diesem Test wurde geprüft, ob abgefangene, bereits gesendete Nachrichten wieder akzeptiert werden. Dazu wurde eine verschlüsselte Nachricht im Burp-Proxy abgefangen und über den Repeater erneut gesendet.

Der Empfänger erkannte die Wiederholung sofort und wies sie ab:
*"attempted to send message with duplicate nonce"*.

Wurde das `nonce` künstlich verändert, schlug die Entschlüsselung fehl:

*"attempted to send message but decryption failed: AES decryption failed"*.

Damit greifen sowohl die Nonce-Überprüfung als auch die Integritätsprüfung der symmetrischen Verschlüsselung ein.

#figure(
  caption: [Replay-Angriff Screenshot],
  image("Burp Screenshots/repeat_nonce.png"),
)

== Manipulation des Handshakes (SYN/ACK)

Hier wurde getestet, ob der Handshake durch eine MITM-Manipulation beeinflussbar ist. Ein ACK-Paket wurde im Intercept verändert, indem ein Byte im Payload geändert wurde, und anschließend erneut gesendet.

Der Server lehnte das Paket aufgrund einer ungültigen Signatur ab:
*"attempted to send ACK but signature invalid: Verification equation was not satisfied"*.
Damit ist bestätigt, dass der Handshake dank kryptografischer Signaturen zuverlässig gegen Manipulation geschützt ist.

== Unautorisierte Nachricht ohne Handshake

Schlißlich wurde geprüft, ob verschlüsselte Nachrichten außerhalb einer gültigen Sitzung akzeptiert werden. Dazu wurde eine formal gültige, aber nicht zu einer bestehenden Sitzung gehörende `EncryptedMessage` im Repeater erzeugt und an den Proxy gesendet.

Das Paket wurde abgewiesen, da keine passende Sitzung existierte:
*"attempted to send message but chat does not exist"*.
Damit wird klar, dass Nachrichten ohne vorausgehenden Handshake technisch nicht akzeptiert werden können.

== Fazit

Die durchgeführten Sicherheitstests zeigen, dass die Schutzmechanismen effektiv gegen diese Angriffsvektoren schützen. Replay-Angriffe werden durch Nonce-Überprüfung und Zeitstempelvalidierung verhindert. Manipulationsversuche während des Handshakes werden durch Signaturen erkannt und abgewiesen. Zudem akzeptiert die Anwendung keine Nachrichten ohne vorherigen, gültigen Handshake, wodurch unautorisierte Kommunikation unterbunden wird. Insgesamt zeigen die Testergebnisse, dass die Kombination aus Nonces, Signaturen und zeitbasierten Prüfungen einen festen Schutz gegen typische Angriffe bietet und die Sicherheit des End-zu-End-verschlüsselten Protokolls auch in der Praxis gewährleistet.

= Ergebnisse und Reflexion

== Zielsetzung

Die in @ziele genannten Ziele wurden eindeutig erreicht: Es wurde ein Chat-App entwickelt, dessen Protokoll Vertraulichkeit, Integrität, Authentizität, Vertraulichkeit und Forward Secrecy ohne sichtbare Sicherheitslücken erreicht.

// [Gute Logs, Cleaner Code, Docker Compose wurde auch gemacht].

== Unterschiede zu TLS

Das entwickelte Protokoll basiert grundsätzlich auf TLS 1.2, unterscheidet sich jedoch in mehreren Punkten. Diese Abweichungen sind bewusst gewählt, da eine klassische TLS-Implementierung nicht optimal zu den Anforderungen einer Ende-zu-Ende-verschlüsselten Chat-App passt. Während TLS primär für HTTPS und Webseiten entwickelt wurde, ist dieses Protokoll ausschließlich für eine Chat-App gedacht. Deshalb konnten gewisse Teile des TLS wie Zertifikate weggelassen werden.

=== X.509-Zertifikate

TLS setzt auf *X.509-Zertifikate*, die eine komplexe *PKI* (Public Key Infrastructure) erfordern. Für eine Chat-Anwendung würde dieser Ansatz unnötigen administrativen Aufwand und zusätzliche Angriffsflächen erzeugen.

Stattdessen verwendet das entwickelte Protokoll reine Ed25519-Schlüssel ohne Zertifikatsschicht, was die Komplexität deutlich reduziert. Da die Vertrauensbeziehungen innerhalb der App ohnehin über benutzerkontrollierte Schlüssel und nicht über DNS-basierte Identitäten geregelt werden, bietet ein Zertifikatsmodell keinen Mehrwert.

=== Beidseitige Authentifizierung

In TLS ist nur der Server zur Authentifizierung verpflichtet. Client-Zertifikate existieren zwar, kommen in der Praxis aber kaum vor.

Für einen *End-to-End-Chat* ist jedoch zwingend erforderlich, dass beide Kommunikationspartner ihre Identität beweisen. Daher signieren sowohl der Client als auch der Server den gesamten Handshake. Dadurch wird sichergestellt, dass der Proxy keine Rollen vortäuschen oder Nachrichten in fremdem Namen erzeugen kann.

=== Vereinfachter und minimalistisch gehaltener Handshake

Im Gegensatz zu TLS, das zahlreiche zusätzliche Informationen austauschen muss (*Protokollversionen, Cipher-Suites, Extensions, Kompressionsverfahren, Session-IDs, Tickets* usw.), operiert das hier entwickelte System in einer vollständig *kontrollierten Umgebung*. Dadurch sind *keine Verhandlungen* erforderlich: Es existiert nur *eine Protokollversion*, alle Clients verwenden *denselben Cipher-Suite* (X25519 + Ed25519 + AES-256-GCM + SHA-256) und es gibt *keine optionalen Erweiterungen*. Die Vielfalt klassischer TLS-Kompatibilitätsmechanismen wird somit nicht benötigt.

Dies verhindert Fehlkonfigurationen und reduziert die Angriffsfläche.

// - Protokollentwicklung brauchte viel mehr Iterationen als erwartet. Keine Sache darf vergessen werden, sonst kann die App unsicher werden.
// - Rust war für die sicherheit eine große Hilfe, zur Zeit aber auch schwierig zum schreiben. Z. B. ist der Typ des Nonces `GenericArray<u8, U12>`, wo die Library überall die selbe Version haben muss und was viel Zeit gekostet hat.
// - Rust und Vue funktionieren wegen wasm-bindgen wirklich gut miteinander. Aber es was nicht so einfach den Setup für sie zu machen. Die Dokumentation war etwas holprig und unerwartete Fehler sind oft aufgetreten.
// - Vue ist ein sehr gutes Framework. Es gab fast keine Fehler und Interationen waren sehr schnell
// - Die gratis Version von Burp Suite gab mir alles was ich brauchte und was überraschenderweise sehr einfach zu verwenden. (Intercept, Repeater).
// - ChatGPT was ein sehr gutes Startpunkt für die Recherche. Ich konnte schnell sehen, was in meinem Protokoll gut und was schlecht ist und konnte Protokoll einfach mit TLS vergleichen. Natürlich wurde alles doppelt mit guten Quellen überprüft.
// - Backend-Entwicklung mit Tokio ist echt schwierig. Ich konnte aber eine gute Vorlage für den Proxy finden und damit die App ziemlich schnell entwickeln.

== Persönliche Erkenntnisse

// Die Arbeit am Projekt hat mir gezeigt, dass Entwicklung oft anders läuft, als man plant. Besonders die Protokollentwicklung brauchte viel mehr Versuche (Iterationen) als gedacht. Mir wurde klar: Man darf nichts vergessen, sonst wird die App schnell unsicher.

// Rust war super für die Sicherheit, aber es war auch schwer zu programmieren. Zum Beispiel war der Typ für den Nonce `GenericArray<u8, U12>` kompliziert. Alle Programmteile mussten genau die gleiche Version dieser Anweisung haben, was viel Zeit gekostet hat.

// Dank `wasm-bindgen` haben Rust und Vue am Ende sehr gut zusammengearbeitet. Der Start-Setup war allerdings mühsam. Die Anleitungen (Dokumentation) waren nicht immer klar, und es traten oft unerwartete Fehler auf.

// Vue selbst war ein ausgezeichnetes Framework. Es gab fast keine Fehler, und ich konnte sehr schnell neue Dinge ausprobieren.

// Die Gratisversion der Burp Suite hat mir alles gegeben, was ich brauchte (Intercept, Repeater) und war überraschend einfach zu bedienen.

// ChatGPT war ein guter Startpunkt für die Recherche. Ich konnte schnell sehen, was an meinem Protokoll gut oder schlecht ist und es leicht mit Standards wie TLS vergleichen. Ich habe aber immer alles mit guten Quellen überprüft.

// Die Backend-Entwicklung mit Tokio war echt schwierig. Glücklicherweise fand ich eine brauchbare Vorlage für den Proxy, mit der ich die App dann doch relativ schnell fertigstellen konnte.

Dieses Projekt wies viel mehr Schwierigkeiten auf als ursprünglich geplant. Das Projekt zeigt die Bedeutung der vollständigen Abdeckung aller Sicherheitsaspekte (*Security by Design* statt *Security by Obscurity*), da deren Vernachlässigung Sicherheitslücken einbringen könnte.

=== Rust und Herausforderungen in der Implementierung

Die Wahl von Rust bot signifikante Vorteile für die Speicher- und Typsicherheit. Die Implementierung war jedoch sehr zeitaufwendig. Ein Beispiel hierfür war die Verwendung komplexer, generischer Typen, wie `GenericArray<u8,U12>` für den Nonce. Dies erforderte eine strikte Versions- und Typenkonsistenz über alle Abhängigkeiten, was die Entwicklungszeit deutlich verlängerte.

=== Frontend-Integration und Ökosystem-Tools

Die Integration von Rust und Vue.js wurde durch das Tool `wasm-bindgen` erfolgreich realisiert. Die initiale Einrichtung (Setup) war jedoch von Komplexität geprägt. Die verfügbare Dokumentation ist teilweise mangelhaft, was zu einer Häufung unerwarteter Konfigurations- und Kompilierungsfehler führte.

Das Vue.js Framework erwies sich hingegen als sehr stabil und effizient. Die Entwicklung neuer Funktionen konnte mit hoher Geschwindigkeit und wenigen Fehlern durchgeführt werden, was die Produktivität signifikant steigerte.

=== Tools zur Sicherheitsanalyse und Recherche

Die kostenfreie Version der Burp Suite (Community Edition) besitzt mit den Funktionen "Intercept" und "Repeater" alle notwendigen Werkzeuge für die Sicherheitsanalyse und ist sehr benutzerfreundlich.

ChatGPT diente als wertvolle Ausgangsbasis für initiale Recherchen und zur schnellen Validierung von Protokolleigenschaften im Vergleich zu etablierten Standards wie TLS. Es wurde jedoch stets darauf geachtet, alle generierten Informationen kritisch zu prüfen und durch anerkannte Quellen zu verifizieren.

=== Backend-Entwicklung

Die Backend-Entwicklung unter Verwendung des asynchronen Runtimes Tokio stellte die größte technische Hürde dar. Die Komplexität konnte schließlich durch die Adaption einer ähnlichen Proxy-Implementierungsvorlage überwunden werden, was eine verhältnismäßig zügige Finalisierung des Backends ermöglichte.

= Einsatzmöglichkeiten und Ausblick

Die entwickelte Chat-Applikation bietet bereits jetzt die wichtigsten Kommunikationsfunktionen. Die Hauptanwendung liegt im direkten Austausch von Nachrichten zwischen Benutzern. Ein besonderer Fokus liegt auf den sicheren Austausch von sensiblen Informationen, wie etwa Passwörtern, da die Kommunikationswege entsprechend geschützt sind.

Über die erreichten Ziele und den aktuellen Umfang dieser Arbeit hinaus eröffnen sich verschiedene theoretische Weiterentwicklungsmöglichkeiten für die Anwendung. Diese potenziellen Funktionen skizzieren das langfristige Potenzial des entwickelten Systems, sind jedoch explizit nicht Teil der Zielsetzung dieser Arbeit und wären Gegenstand zukünftiger Projekte:

- *Effizientere Verbindungsverwaltung*: Es wäre technisch möglich, Mechanismen zu implementieren, die es der Anwendung erlauben, bestehende Verbindungen fortzusetzen und wiederherzustellen, anstatt nach einer Unterbrechung stets einen neuen Verbindungsaufbau initiieren zu müssen.
- *Vereinfachte Schlüsselverwaltung*: Der Austausch der kryptografischen Schlüssel könnte durch eine einfachere Methode optimiert werden. Anstatt die 32 Bytes manuell zu teilen, könnte dies beispielsweise über die Generierung und das Scannen eines QR-Codes erfolgen.
- *Erweiterung um Gruppenchats*: Eine denkbare funktionale Erweiterung ist die Implementierung von Gruppenchats, um die Kommunikation mehrerer Teilnehmer in einem gemeinsamen Kanal zu ermöglichen.
- *Horizontale Skalierung*: Im Hinblick auf Skalierbarkeit und Hochverfügbarkeit wäre die theoretische Unterstützung von mehreren Servern notwendig, um eine potenziell größere Benutzerbasis und eine bessere Lastverteilung zu gewährleisten.

= Anhang

Um die praktische Umsetzung dieser Arbeit sowie den Entstehungsprozess nachvollziehbar zu machen, wurden alle relevanten Ressourcen online zur Verfügung gestellt. Unter der folgenden URL findet sich eine begleitende Website, die als zentraler Einstiegspunkt dient:

* https://aba.antonaparin.com *

Diese Webseite enthält Verweise auf die folgenden Komponenten:

- *Live-Demo der Chat-App*: Über die Website kann die entwickelte Applikation direkt aufgerufen und in einer Live-Umgebung getestet werden.
- *Zentrales GitHub-Repository*: Hier findet sich der vollständige Quellcode des gesamten Projekts. Dies umfasst:
  - Den Programmcode der modernen Chat-App (Frontend/Backend).
  - Den Typst-Quellcode, aus dem diese schriftliche Arbeit generiert wurde.
- *PDF-Version der Arbeit*: Für den schnellen Zugriff ist die bereits kompilierte PDF-Datei der Arbeit ebenfalls auf der Website hinterlegt.

#v(1cm)

#figure(caption: [https://aba.antonaparin.com QR-Code])[
  #tiaoma.barcode("https://aba.antonaparin.com", "QRCode", options: (scale: 5.,)
  )
]

#bibliography("bib.bib", full: true, title: "Literaturverzeichnis", style: "ieee")

// #text(gray)[#total-words Wörter, #total-characters Zeichen (exkl. Inhaltsverzeichnis, Quellenverzeichnis und Leerzeichen)]

#[
  #show outline: set heading(outlined: true)
  #outline(target: figure, title: "Abbildungsverzeichnis")
]

Alle Abbildungen, Listings und Tabellen stammen von *Anton Aparin*

#text(fill: white)[six seven]
