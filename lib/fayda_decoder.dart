/// Offline decoder and signature verifier for the QR code on the Ethiopian
/// Fayda national ID card.
///
/// - [decodePayload]: you already have the QR text (from a camera scanner).
/// - [decodeImage]: you have a photo (JPEG, PNG, WebP, ...).
/// - [decodeImageData]: you have raw RGBA pixels.
/// - [verifySignature]: check the card's RS256 signature against NIDP's key.
///
/// Community project. Not affiliated with or endorsed by Ethiopia's National
/// ID Program (NIDP).
library;

export 'src/parser.dart' show decodePayload;
export 'src/pipeline.dart' show decodeImage, decodeImageData, imageBytesToRgba;
export 'src/pixels.dart' show RgbaImage;
export 'src/qr_scanner.dart'
    show
        QrScan,
        QrScanDecoded,
        QrScanNone,
        QrScanUnreadable,
        QrScanner,
        ZxingQrScanner;
export 'src/result.dart';
export 'src/verify.dart'
    show
        KeySource,
        SignatureVerification,
        VerificationFailureReason,
        faydaV4PublicKeyPem,
        verifySignature;
export 'src/version.dart' show libraryName, libraryVersion;
