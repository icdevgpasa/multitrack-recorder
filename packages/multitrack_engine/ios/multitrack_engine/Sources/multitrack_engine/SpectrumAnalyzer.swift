import Accelerate
import Foundation

/// Log-spaced band levels (0...1) from a 1024-point FFT, for visuals only.
/// Not thread-safe: the caller serialises access.
final class SpectrumAnalyzer {
  private let n = 1024
  private let log2n = vDSP_Length(10)
  private let setup: FFTSetup
  private var window: [Float]
  private var input: [Float]
  private var history: [Float]
  private var real: [Float]
  private var imag: [Float]
  private var mags: [Float]
  private(set) var levels: [Float]
  let bands: Int

  init(bands: Int = 24) {
    self.bands = bands
    setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    window = [Float](repeating: 0, count: n)
    vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
    input = [Float](repeating: 0, count: n)
    history = [Float](repeating: 0, count: n)
    real = [Float](repeating: 0, count: n / 2)
    imag = [Float](repeating: 0, count: n / 2)
    mags = [Float](repeating: 0, count: n / 2)
    levels = [Float](repeating: 0, count: bands)
  }

  deinit {
    vDSP_destroy_fftsetup(setup)
  }

  /// Adds `count` new samples (mono) and analyses the latest 1024.
  func process(_ samples: UnsafePointer<Float>, count: Int, sampleRate: Double) {
    guard count > 0, sampleRate > 0 else { return }
    if count >= n {
      history.withUnsafeMutableBufferPointer { h in
        h.baseAddress!.update(from: samples.advanced(by: count - n), count: n)
      }
    } else {
      history.withUnsafeMutableBufferPointer { h in
        let base = h.baseAddress!
        memmove(base, base.advanced(by: count), (n - count) * MemoryLayout<Float>.stride)
        base.advanced(by: n - count).update(from: samples, count: count)
      }
    }
    vDSP_vmul(history, 1, window, 1, &input, 1, vDSP_Length(n))

    let half = n / 2
    real.withUnsafeMutableBufferPointer { rp in
      imag.withUnsafeMutableBufferPointer { ip in
        var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
        input.withUnsafeBufferPointer { inp in
          inp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { cplx in
            vDSP_ctoz(cplx, 2, &split, 1, vDSP_Length(half))
          }
        }
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))
      }
    }

    let binHz = sampleRate / Double(n)
    let fMin = 40.0
    let fMax = min(16_000.0, sampleRate / 2)
    let ratio = fMax / fMin
    let scale = Float(n) / 4  // rough full-scale magnitude for a windowed sine
    for b in 0..<bands {
      let f0 = fMin * pow(ratio, Double(b) / Double(bands))
      let f1 = fMin * pow(ratio, Double(b + 1) / Double(bands))
      let lo = max(1, Int(f0 / binHz))
      let hi = min(half - 1, max(lo, Int(f1 / binHz)))
      var peak: Float = 0
      for i in lo...hi { peak = max(peak, mags[i]) }
      let db = 20 * log10(max(peak / scale, 1e-6))
      let value = max(0, min(1, (db + 60) / 60))
      // Fast rise, slow fall.
      levels[b] = value > levels[b] ? value : levels[b] * 0.82 + value * 0.18
    }
  }

  func decay() {
    for b in 0..<bands { levels[b] *= 0.8 }
  }
}
