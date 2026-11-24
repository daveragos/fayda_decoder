/// Read and verify the QR code on the Ethiopian Fayda national ID card,
/// entirely on-device.
///
/// - [decodePayload]: you have the QR text, for example from a camera
///   scanner. [isFaydaPayload] filters scanner callbacks cheaply.
/// - [decodeImageInBackground]: you have a photo (JPEG, PNG, WebP, ...).
///   [decodeImage] does the same on the calling isolate.
/// - [decodeImageDataInBackground]: you have raw pixels, for example a
///   camera frame via [RgbaImage.fromLuminance] or [RgbaImage.fromBgra].
/// - [verifySignature], or `result.verify()`: check the card's RS256
///   signature against NIDP's key.
///
/// For tests, `package:fayda_decoder/testing.dart` builds synthetic signed
/// cards and QR images.
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
