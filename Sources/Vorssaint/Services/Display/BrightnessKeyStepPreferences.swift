import Foundation

extension BrightnessService {
    /// Read at each press. Retaining a saved step never rearms a revoked tap.
    var keyStep: BrightnessSupport.KeyStep {
        BrightnessKeyStepActivation.effective(in: UserDefaults.standard)
    }
}
