import SwiftUI

// Heavy grain for cards
struct CardGrainTexture: View {
    var body: some View {
        Image(uiImage: generateCardGrainImage())
            .resizable(resizingMode: .tile)
    }
    
    func generateCardGrainImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            for _ in 0..<1200 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let gray = CGFloat.random(in: 0.5...0.85)
                let alpha = CGFloat.random(in: 0.5...0.95)
                
                UIColor(white: gray, alpha: alpha).setFill()
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(rect)
            }
        }
        return image
    }
}

// Light grain for background
struct BackgroundGrainTexture: View {
    var body: some View {
        Image(uiImage: generateBackgroundGrainImage())
            .resizable(resizingMode: .tile)
    }
    
    func generateBackgroundGrainImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            for _ in 0..<10000 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let gray = CGFloat.random(in: 0.7...0.9)
                let alpha = CGFloat.random(in: 0.2...0.4)
                
                UIColor(white: gray, alpha: alpha).setFill()
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(rect)
            }
        }
        return image
    }
}

// Card style modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 33)
                        .fill(Color.white)
                    
                    CardGrainTexture()
                        .opacity(0.35)
                        .clipShape(RoundedRectangle(cornerRadius: 33))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 33)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// Background with grain
struct GrainBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.90, green: 0.90, blue: 0.92)
            
            BackgroundGrainTexture()
                .opacity(0.1)
        }
        .ignoresSafeArea()
    }
}
