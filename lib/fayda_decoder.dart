/// Offline decoder and signature verifier for the QR code on the Ethiopian
/// Fayda national ID card.
///
/// - [decodePayload]: you already have the QR text (from a camera scanner).
///   [isFaydaPayload] filters scanner callbacks cheaply.
/// - [decodeImage]: you have a photo (JPEG, PNG, WebP, ...).
///   [decodeImageInBackground] does the same off the UI isolate.
/// - [decodeImageData]: you have raw pixels, for example a camera frame via
///   [RgbaImage.fromLuminance] or [RgbaImage.fromBgra].
/// - [verifySignature]: check the card's RS256 signature against NIDP's key.
///
/// Community project. Not affiliated with or endorsed by Ethiopia's National
/// ID Program (NIDP).
library;

export 'src/background.dart'
    show decodeImageDataInBackground, decodeImageInBackground;
export 'src/parser.dart' show decodePayload, isFaydaPayload;
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
        FaydaSuccessVerification,
        KeySource,
        SignatureVerification,
        VerificationFailureReason,
        faydaV4PublicKeyPem,
        verifySignature;
export 'src/version.dart' show libraryName, libraryVersion;
