import Foundation
import Combine

class DataStore: ObservableObject {
    @Published var buttons: [SoundButton] = []
    @Published var categories: [Category] = []
    
    private let buttonsKey = "soundButtons"
    private let categoriesKey = "categories"
    
    init() {
        loadData()
        if categories.isEmpty {
            categories = [
                Category(name: "Goals", colorHex: "#34C759"),
                Category(name: "Penalties", colorHex: "#FF3B30"),
                Category(name: "Timeouts", colorHex: "#FF9500"),
                Category(name: "Warmup", colorHex: "#007AFF"),
                Category(name: "Celebrations", colorHex: "#AF52DE")
            ]
            saveCategories()
        }
    }
    
    func addButton(_ button: SoundButton) {
        var newButton = button
        newButton.order = buttons.count
        buttons.append(newButton)
        saveButtons()
    }
    
    func updateButton(_ button: SoundButton) {
        if let index = buttons.firstIndex(where: { $0.id == button.id }) {
            buttons[index] = button
            saveButtons()
        }
    }
    
    func deleteButton(_ button: SoundButton) {
        buttons.removeAll { $0.id == button.id }
        saveButtons()
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        for i in buttons.indices {
            buttons[i].categoryTags.removeAll { $0 == category.name }
        }
        saveCategories()
        saveButtons()
    }
    
    func moveButton(from source: IndexSet, to destination: Int) {
        buttons.move(fromOffsets: source, toOffset: destination)
        for i in buttons.indices {
            buttons[i].order = i
        }
        saveButtons()
    }
    
    private func saveButtons() {
        if let encoded = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(encoded, forKey: buttonsKey)
        }
    }
    
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: buttonsKey),
           let decoded = try? JSONDecoder().decode([SoundButton].self, from: data) {
            buttons = decoded.sorted { $0.order < $1.order }
        }
        
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decoded
        }
    }
}
