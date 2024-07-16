import SwiftUI

struct QRCodeView: View {
    let qrCode: String
    
    var body: some View {
        Image(uiImage: generateQRCode(from: qrCode))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
