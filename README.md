# CipherChat, Abschlißende Arbeit von Anton Aparin

## Abstract

Diese Abschlussarbeit beschäftigt sich mit der Entwicklung einer kryptografisch sicheren und modernen Messenger-App. Ziel der Arbeit ist es, ein eigenes, TLS-ähnliches
Kommunikationsprotokoll umzusetzen, um die Funktionsweise moderner Sicherheitsprotokolle besser zu verstehen. Zentral sind dabei die Sicherheitsziele Vertraulichkeit,
Integrität, Authentizität und Forward Secrecy.
Zu Beginn werden die theoretischen Grundlagen der Kryptografie erläutert, darunter
Hashfunktionen, digitale Signaturen, Schlüsselaustauschverfahren sowie symmetrische Verschlüsselung. Darauf aufbauend wird das Transport-Layer-Security-Protokoll
(TLS) analysiert und als Grundlage für ein vereinfachtes, speziell auf einen Messenger
zugeschnittenes Protokoll genommen. Dieses verwendet moderne Algorithmen wie
Ed25519, X25519 und AES-GCM.
Im nächsten Teil wird der Messenger vollständig implementiert. Die Architektur besteht
aus einem Proxy-Backend, einem Web-Frontend sowie einer in WebAssembly ausgeführten kryptografischen Logik, die in Rust entwickelt wurde.
Abschließend wird das Protokoll in einem professionellen Penetration-Testing-Programm getestet und analysiert. Die Ergebnisse zeigen, dass das entwickelte System
die definierten Sicherheitsziele erfüllt und einen funktionierenden, Ende-zu-Ende-verschlüsselten Nachrichtenaustausch ermöglicht.
