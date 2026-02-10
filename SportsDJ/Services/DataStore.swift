import Foundation
import Combine

class DataStore: ObservableObject {
    @Published var buttons: [SoundButton] = []
    @Published var categories: [Category] = []
    @Published var events: [Event] = []
    @Published var selectedEventID: UUID?
    
    private let buttonsKey = "soundButtons"
    private let categoriesKey = "categories"
    private let eventsKey = "events"
    private let selectedEventKey = "selectedEvent"
    
    init() {
        loadData()
        migrateDataIfNeeded()
        if categories.isEmpty {
            categories = [
                Category(name: "Goals", colorHex: "#34C759", iconName: "sportscourt.fill"),
                Category(name: "Penalties", colorHex: "#FF3B30", iconName: "exclamationmark.triangle.fill"),
                Category(name: "Timeouts", colorHex: "#FF9500", iconName: "pause.circle.fill"),
                Category(name: "Warmup", colorHex: "#007AFF", iconName: "flame.fill"),
                Category(name: "Celebrations", colorHex: "#AF52DE", iconName: "party.popper.fill")
            ]
            saveCategories()
        }
    }
    
    // MARK: - Event Filtering
    
    var filteredCategories: [Category] {
        categories.filter { category in
            category.isGlobal || category.eventID == selectedEventID
        }
    }
    
    var filteredButtons: [SoundButton] {
        buttons.filter { button in
            button.eventID == nil || button.eventID == selectedEventID
        }
    }
    
    // MARK: - Button Methods
    
    func addButton(_ button: SoundButton) {
        var newButton = button
        newButton.order = buttons.count
        newButton.eventID = selectedEventID
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
    
    func moveButton(from source: IndexSet, to destination: Int) {
        buttons.move(fromOffsets: source, toOffset: destination)
        for i in buttons.indices {
            buttons[i].order = i
        }
        saveButtons()
    }
    
    // MARK: - Category Methods
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
    }
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        for i in buttons.indices {
            buttons[i].categoryTags.removeAll { $0 == category.name }
        }
        saveCategories()
        saveButtons()
    }
    
    // MARK: - Event Methods
    
    func addEvent(_ event: Event) {
        events.append(event)
        saveEvents()
    }
    
    func updateEvent(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()
        }
    }
    
    func deleteEvent(_ event: Event) {
        // Delete all categories specific to this event
        categories.removeAll { $0.eventID == event.id }
        
        // Delete all buttons specific to this event
        buttons.removeAll { $0.eventID == event.id }
        
        // Remove the event
        events.removeAll { $0.id == event.id }
        
        // Clear selection if deleted event was selected
        if selectedEventID == event.id {
            selectedEventID = nil
        }
        
        saveEvents()
        saveCategories()
        saveButtons()
    }
    
    func selectEvent(_ event: Event?) {
        selectedEventID = event?.id
        UserDefaults.standard.set(selectedEventID?.uuidString, forKey: selectedEventKey)
    }
    
    // MARK: - Persistence
    
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
    
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
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
        
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([Event].self, from: data) {
            events = decoded
        }
        
        if let eventIDString = UserDefaults.standard.string(forKey: selectedEventKey) {
            selectedEventID = UUID(uuidString: eventIDString)
        }
    }
    
    // MARK: - Migration for existing data
    
    private func migrateDataIfNeeded() {
        // Migrate buttons that don't have musicSource
        var needsSave = false
        for i in buttons.indices {
            if buttons[i].spotifyURI == nil && buttons[i].musicSource != .appleMusic {
                // This shouldn't happen but handle gracefully
                needsSave = true
            }
        }
        
        // Migrate categories that don't have iconName
        for i in categories.indices {
            if categories[i].iconName.isEmpty {
                categories[i] = Category(
                    name: categories[i].name,
                    colorHex: categories[i].colorHex,
                    eventID: categories[i].eventID,
                    iconName: "tag.fill"
                )
                needsSave = true
            }
        }
        
        if needsSave {
            saveButtons()
            saveCategories()
        }
    }
}
