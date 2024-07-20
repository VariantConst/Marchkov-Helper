import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let qrCode: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            Image(uiImage: generateQRCode(from: qrCode))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding(10)
                .background(Color(colorScheme == .light ? UIColor(white: 0.95, alpha: 1.0) :UIColor(white: 0.8, alpha: 1.0)))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            
            let colorParameters: [String: Any] = [
                "inputColor0": CIColor(color: colorScheme == .light ? UIColor.darkGray : UIColor.black),
                "inputColor1": CIColor(color: colorScheme == .light ? UIColor(white: 0.95, alpha: 1.0) : UIColor(white: 0.8, alpha: 1.0))
            ]
            
            let coloredQRCode = transformedImage.applyingFilter("CIFalseColor", parameters: colorParameters)
            
            if let cgimg = context.createCGImage(coloredQRCode, from: coloredQRCode.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
