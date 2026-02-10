import SwiftUI

struct ManageView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab: ManageTab = .events
    
    enum ManageTab: String, CaseIterable {
        case events = "Events"
        case categories = "Categories"
        case settings = "Settings"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e"),
                        Color(hex: "#0f0f23")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom segmented control
                    segmentedControl
                    
                    TabView(selection: $selectedTab) {
                        EventsListView()
                            .tag(ManageTab.events)
                        
                        CategoriesListView()
                            .tag(ManageTab.categories)
                        
                        DefaultSettingsView()
                            .tag(ManageTab.settings)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(ManageTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .events ? "calendar.badge.clock" : "tag.fill")
                                .font(.subheadline)
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(selectedTab == tab ? .white : .gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color(hex: "#6366f1") : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
            }
        }
        .background(Color(hex: "#1a1a2e").opacity(0.8))
    }
}

// MARK: - Events List View

struct EventsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddEvent = false
    @State private var newEventName = ""
    @State private var newEventColor = "#6366f1"
    @State private var newEventIcon = "star.fill"
    @State private var newEventDate = Date()
    @State private var includeDateInEvent = false
    
    let colorOptions = [
        "#6366f1", "#8b5cf6", "#ec4899", "#f43f5e",
        "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#06b6d4", "#3b82f6"
    ]
    
    let iconOptions = [
        "star.fill", "trophy.fill", "sportscourt.fill", "figure.run",
        "basketball.fill", "football.fill", "tennisball.fill", "music.mic",
        "party.popper.fill", "flag.checkered"
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Add Event Card
                addEventCard
                
                // Events List
                if dataStore.events.isEmpty {
                    emptyEventsState
                } else {
                    ForEach(dataStore.events) { event in
                        EventCard(event: event)
                    }
                }
            }
            .padding()
        }
        .background(Color.clear)
    }
    
    private var addEventCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#6366f1"))
                Text("Create New Event")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                // Expand/collapse chevron
                if !showingAddEvent {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if showingAddEvent {
                VStack(spacing: 16) {
                    // Event Name
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                        TextField("Event name", text: $newEventName)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Optional Event Date
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                            Text("Include Date")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: $includeDateInEvent)
                                .labelsHidden()
                                .tint(Color(hex: "#6366f1"))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        if includeDateInEvent {
                            HStack {
                                DatePicker("", selection: $newEventDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // Icon Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.caption)
                            .foregroundColor(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button(action: { newEventIcon = icon }) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(newEventIcon == icon ? Color(hex: newEventColor) : .gray)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                newEventIcon == icon ?
                                                Color(hex: newEventColor).opacity(0.2) :
                                                Color.white.opacity(0.1)
                                            )
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(newEventIcon == icon ? Color(hex: newEventColor) : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.self) { color in
                                Button(action: { newEventColor = color }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: newEventColor == color ? 3 : 0)
                                        )
                                        .scaleEffect(newEventColor == color ? 1.1 : 1.0)
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation { showingAddEvent = false }
                            newEventName = ""
                            includeDateInEvent = false
                        }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Button(action: addEvent) {
                            Text("Create")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .disabled(newEventName.isEmpty)
                        .opacity(newEventName.isEmpty ? 0.5 : 1)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            if !showingAddEvent {
                withAnimation(.spring(response: 0.3)) {
                    showingAddEvent = true
                }
            }
        }
        .animation(.spring(response: 0.3), value: includeDateInEvent)
    }
    
    private var emptyEventsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Events Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Create your first event to organize\nyour sound buttons by occasion")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    private func addEvent() {
        guard !newEventName.isEmpty else { return }
        let event = Event(
            name: newEventName,
            date: includeDateInEvent ? newEventDate : nil,
            colorHex: newEventColor,
            iconName: newEventIcon
        )
        dataStore.addEvent(event)
        // Auto-select newly created event
        dataStore.selectEvent(event)
        newEventName = ""
        newEventColor = "#6366f1"
        newEventIcon = "star.fill"
        newEventDate = Date()
        includeDateInEvent = false
        withAnimation { showingAddEvent = false }
    }
}

struct EventCard: View {
    @EnvironmentObject var dataStore: DataStore
    let event: Event
    @State private var showingDeleteAlert = false
    @State private var showingLastEventAlert = false
    
    var buttonCount: Int {
        dataStore.buttons.filter { $0.eventID == event.id }.count
    }
    
    var categoryCount: Int {
        dataStore.categories.filter { $0.eventID == event.id }.count
    }
    
    var isLastEvent: Bool {
        dataStore.events.count <= 1
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: event.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        colors: [Color(hex: event.colorHex), Color(hex: event.colorHex).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Show date if available
                if let date = event.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(Color(hex: event.colorHex))
                }
                
                HStack(spacing: 12) {
                    Label("\(buttonCount) sounds", systemImage: "speaker.wave.2.fill")
                    Label("\(categoryCount) categories", systemImage: "tag.fill")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Selected indicator
            if dataStore.selectedEventID == event.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#22c55e"))
                    .font(.title3)
            }
            
            // Delete button (disabled for last event)
            Button(action: {
                if isLastEvent {
                    showingLastEventAlert = true
                } else {
                    showingDeleteAlert = true
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(isLastEvent ? .gray.opacity(0.4) : .red.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            dataStore.selectedEventID == event.id ?
                            Color(hex: event.colorHex).opacity(0.5) :
                            Color.white.opacity(0.1),
                            lineWidth: dataStore.selectedEventID == event.id ? 2 : 1
                        )
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                // Always select the tapped event (no deselection)
                dataStore.selectEvent(event)
            }
        }
        .alert("Delete Event?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dataStore.deleteEvent(event)
            }
        } message: {
            Text("This will also delete all categories and sound buttons specific to this event.")
        }
        .alert("Cannot Delete", isPresented: $showingLastEventAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You must have at least one event. Create another event before deleting this one.")
        }
    }
}

// MARK: - Categories List View

struct CategoriesListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = "#6366f1"
    @State private var newCategoryIcon = "tag.fill"
    @State private var isGlobalCategory = true
    
    let colorOptions = [
        "#6366f1", "#8b5cf6", "#ec4899", "#f43f5e",
        "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#06b6d4", "#3b82f6"
    ]
    
    let iconOptions = [
        "tag.fill", "music.note", "flame.fill", "bolt.fill",
        "star.fill", "heart.fill", "flag.fill", "bell.fill",
        "megaphone.fill", "sparkles"
    ]
    
    var globalCategories: [Category] {
        dataStore.categories.filter { $0.isGlobal }
    }
    
    var eventCategories: [Category] {
        guard let eventID = dataStore.selectedEventID else { return [] }
        return dataStore.categories.filter { $0.eventID == eventID }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Add Category Card
                addCategoryCard
                
                // Global Categories Section
                if !globalCategories.isEmpty {
                    sectionHeader("Global Categories", icon: "globe")
                    ForEach(globalCategories) { category in
                        CategoryCard(category: category)
                    }
                }
                
                // Event-Specific Categories Section
                if let event = dataStore.events.first(where: { $0.id == dataStore.selectedEventID }) {
                    sectionHeader("\(event.name) Categories", icon: "calendar")
                    if eventCategories.isEmpty {
                        Text("No categories for this event")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(eventCategories) { category in
                            CategoryCard(category: category)
                        }
                    }
                }
                
                if globalCategories.isEmpty && eventCategories.isEmpty {
                    emptyCategoriesState
                }
            }
            .padding()
        }
        .background(Color.clear)
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#6366f1"))
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var addCategoryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#6366f1"))
                Text("Create New Category")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if showingAddCategory {
                VStack(spacing: 16) {
                    // Category Name
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                        TextField("Category name", text: $newCategoryName)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Global vs Event-Specific Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Availability")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(isGlobalCategory ? "Available in all events" : "Only in selected event")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Toggle("", isOn: $isGlobalCategory)
                            .labelsHidden()
                            .tint(Color(hex: "#6366f1"))
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    if !isGlobalCategory && dataStore.selectedEventID == nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Select an event first to create event-specific categories")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Icon Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.caption)
                            .foregroundColor(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button(action: { newCategoryIcon = icon }) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(newCategoryIcon == icon ? Color(hex: newCategoryColor) : .gray)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                newCategoryIcon == icon ?
                                                Color(hex: newCategoryColor).opacity(0.2) :
                                                Color.white.opacity(0.1)
                                            )
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(newCategoryIcon == icon ? Color(hex: newCategoryColor) : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.self) { color in
                                Button(action: { newCategoryColor = color }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: newCategoryColor == color ? 3 : 0)
                                        )
                                        .scaleEffect(newCategoryColor == color ? 1.1 : 1.0)
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation { showingAddCategory = false }
                            newCategoryName = ""
                        }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Button(action: addCategory) {
                            Text("Create")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#6366f1"), Color(hex: "#8b5cf6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .disabled(newCategoryName.isEmpty || (!isGlobalCategory && dataStore.selectedEventID == nil))
                        .opacity(newCategoryName.isEmpty || (!isGlobalCategory && dataStore.selectedEventID == nil) ? 0.5 : 1)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            if !showingAddCategory {
                withAnimation(.spring(response: 0.3)) {
                    showingAddCategory = true
                }
            }
        }
    }
    
    private var emptyCategoriesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Categories Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Create categories to organize\nyour sound buttons")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    private func addCategory() {
        guard !newCategoryName.isEmpty else { return }
        let category = Category(
            name: newCategoryName,
            colorHex: newCategoryColor,
            eventID: isGlobalCategory ? nil : dataStore.selectedEventID,
            iconName: newCategoryIcon
        )
        dataStore.addCategory(category)
        newCategoryName = ""
        newCategoryColor = "#6366f1"
        newCategoryIcon = "tag.fill"
        withAnimation { showingAddCategory = false }
    }
}

struct CategoryCard: View {
    @EnvironmentObject var dataStore: DataStore
    let category: Category
    @State private var showingDeleteAlert = false
    
    var buttonCount: Int {
        dataStore.buttons.filter { $0.categoryTags.contains(category.name) }.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: category.iconName)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: category.colorHex))
                .cornerRadius(12)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Label("\(buttonCount) sounds", systemImage: "speaker.wave.2.fill")
                    if category.isGlobal {
                        Label("Global", systemImage: "globe")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Delete button
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .alert("Delete Category?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dataStore.deleteCategory(category)
            }
        } message: {
            Text("This will remove the category from all sound buttons.")
        }
    }
}

// MARK: - Default Settings View

struct DefaultSettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    
    @State private var selectedColor: String = "#6366f1"
    @State private var fadeOutEnabled: Bool = false
    @State private var fadeOutDuration: Double = 2.0
    @State private var selectedCategories: Set<String> = []
    
    let colorOptions = [
        "#6366f1", "#8b5cf6", "#ec4899", "#f43f5e",
        "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#06b6d4", "#3b82f6"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info header
                infoHeader
                
                // Default Color
                colorCard
                
                // Default Categories
                categoriesCard
                
                // Fade Out Settings
                fadeOutCard
            }
            .padding()
        }
        .background(Color.clear)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private var infoHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundColor(Color(hex: "#6366f1"))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Song Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("These settings will be pre-selected when adding new songs")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#6366f1").opacity(0.1))
        )
    }
    
    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Default Button Color", systemImage: "paintpalette")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                ForEach(colorOptions, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                        saveSettings()
                    }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .animation(.spring(response: 0.3), value: selectedColor)
    }
    
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Default Categories", systemImage: "tag")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Text("Pre-select categories for new sounds")
                .font(.caption)
                .foregroundColor(.gray)
            
            if dataStore.filteredCategories.isEmpty {
                Text("No categories available. Create some in the Categories tab.")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dataStore.filteredCategories) { category in
                            Button(action: {
                                if selectedCategories.contains(category.name) {
                                    selectedCategories.remove(category.name)
                                } else {
                                    selectedCategories.insert(category.name)
                                }
                                saveSettings()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: category.iconName)
                                        .font(.caption2)
                                    Text(category.name)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(selectedCategories.contains(category.name) ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategories.contains(category.name) ?
                                    Color(hex: category.colorHex) :
                                    Color.white.opacity(0.1)
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private var fadeOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Default Fade Out", systemImage: "speaker.wave.3.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Fade Out by Default")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("New sounds will have fade out enabled")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $fadeOutEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "#6366f1"))
                    .onChange(of: fadeOutEnabled) { _ in
                        saveSettings()
                    }
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            
            // Duration selector (only show if enabled)
            if fadeOutEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Duration")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        ForEach([1.0, 1.5, 2.0, 3.0, 5.0], id: \.self) { duration in
                            Button(action: {
                                fadeOutDuration = duration
                                saveSettings()
                            }) {
                                Text("\(String(format: "%.1f", duration))s")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(fadeOutDuration == duration ? .white : .gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        fadeOutDuration == duration ?
                                        Color(hex: "#6366f1") :
                                        Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
        .animation(.spring(response: 0.3), value: fadeOutEnabled)
    }
    
    private func loadCurrentSettings() {
        let settings = dataStore.defaultSettings
        selectedColor = settings.colorHex
        fadeOutEnabled = settings.fadeOutEnabled
        fadeOutDuration = settings.fadeOutDuration
        selectedCategories = Set(settings.defaultCategories)
    }
    
    private func saveSettings() {
        let settings = DefaultSongSettings(
            colorHex: selectedColor,
            fadeOutEnabled: fadeOutEnabled,
            fadeOutDuration: fadeOutDuration,
            defaultCategories: Array(selectedCategories),
            startFromBeginning: true
        )
        dataStore.updateDefaultSettings(settings)
    }
}

#Preview {
    ManageView()
        .environmentObject(DataStore())
}
