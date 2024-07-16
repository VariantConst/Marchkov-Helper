import SwiftUI

struct QRCodeView: View {
    let qrCode: String
    
    var body: some View {
        VStack {
            Image(uiImage: generateQRCode(from: qrCode))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 220, height: 220) // 稍微缩小二维码本身
                .padding(20) // 添加内边距
                .background(Color.white)
                .cornerRadius(15) // 增加圆角以配合新的 padding
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                ) // 添加一个微妙的边框
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "L"
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
