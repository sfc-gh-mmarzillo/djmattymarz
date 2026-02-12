import SwiftUI

struct ManageView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab: ManageTab = .events
    
    enum ManageTab: String, CaseIterable {
        case events = "Teams/Events"
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
                            Image(systemName: iconForTab(tab))
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
    
    private func iconForTab(_ tab: ManageTab) -> String {
        switch tab {
        case .events: return "person.3.fill"
        case .categories: return "tag.fill"
        case .settings: return "gearshape.fill"
        }
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
    @State private var isReordering = false
    
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
                // Reorder toggle when multiple events exist
                if dataStore.events.count > 1 {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                isReordering.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.caption)
                                Text(isReordering ? "Done" : "Reorder")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(isReordering ? Color(hex: "#22c55e") : Color(hex: "#6366f1"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isReordering ? Color(hex: "#22c55e").opacity(0.2) : Color(hex: "#6366f1").opacity(0.2))
                            )
                        }
                    }
                }
                
                // Add Event Card (hide when reordering)
                if !isReordering {
                    addEventCard
                }
                
                // Events List
                if dataStore.events.isEmpty {
                    emptyEventsState
                } else {
                    let sortedEvents = dataStore.events.sorted { $0.order < $1.order }
                    ForEach(Array(sortedEvents.enumerated()), id: \.element.id) { index, event in
                        EventCard(
                            event: event,
                            isReordering: isReordering,
                            index: index,
                            totalCount: sortedEvents.count,
                            onMoveUp: {
                                moveEvent(at: index, direction: -1)
                            },
                            onMoveDown: {
                                moveEvent(at: index, direction: 1)
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color.clear)
    }
    
    private func moveEvent(at index: Int, direction: Int) {
        let sortedEvents = dataStore.events.sorted { $0.order < $1.order }
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < sortedEvents.count else { return }
        
        // Create IndexSet for the source and calculate destination
        let source = IndexSet(integer: index)
        let destination = direction > 0 ? newIndex + 1 : newIndex
        
        withAnimation(.spring(response: 0.3)) {
            dataStore.moveEvent(from: source, to: destination)
        }
    }
    
    private var addEventCard: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                Text("Add Event or Team")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            if showingAddEvent {
                VStack(spacing: 16) {
                    // Event Name
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                        TextField("Team or event name", text: $newEventName)
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
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: showingAddEvent ? [] : [8, 4]))
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
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Teams or Events Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Create your first team or event to organize\nyour sounds, categories, and lineup")
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
    var isReordering: Bool = false
    var index: Int = 0
    var totalCount: Int = 1
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    
    @State private var showingDeleteAlert = false
    @State private var showingLastEventAlert = false
    @State private var showingVoiceSettings = false
    
    var buttonCount: Int {
        dataStore.buttons.filter { $0.eventID == event.id }.count
    }
    
    var categoryCount: Int {
        dataStore.categories.filter { $0.eventID == event.id }.count
    }
    
    var isLastEvent: Bool {
        dataStore.events.count <= 1
    }
    
    var hasVoiceSettings: Bool {
        event.defaultVoiceSettings != nil
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
            
            if isReordering {
                // Reorder buttons
                VStack(spacing: 8) {
                    Button(action: { onMoveUp?() }) {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(index > 0 ? .white : .gray.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(index > 0 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(index == 0)
                    
                    Button(action: { onMoveDown?() }) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(index < totalCount - 1 ? .white : .gray.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(index < totalCount - 1 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(index == totalCount - 1)
                }
            } else {
                // Voice settings button
                Button(action: { showingVoiceSettings = true }) {
                    Image(systemName: hasVoiceSettings ? "mic.fill" : "mic")
                        .font(.body)
                        .foregroundColor(hasVoiceSettings ? Color(hex: "#22c55e") : .gray)
                }
                .padding(.trailing, 4)
                
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
        .sheet(isPresented: $showingVoiceSettings) {
            TeamVoiceSettingsView(event: event)
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
    @State private var isReordering = false
    
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
        dataStore.categories.filter { $0.isGlobal }.sorted { $0.order < $1.order }
    }
    
    var eventCategories: [Category] {
        guard let eventID = dataStore.selectedEventID else { return [] }
        return dataStore.categories.filter { $0.eventID == eventID }.sorted { $0.order < $1.order }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Reorder toggle when categories exist
                if !dataStore.categories.isEmpty {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                isReordering.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.caption)
                                Text(isReordering ? "Done" : "Reorder")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(isReordering ? Color(hex: "#22c55e") : Color(hex: "#6366f1"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isReordering ? Color(hex: "#22c55e").opacity(0.2) : Color(hex: "#6366f1").opacity(0.2))
                            )
                        }
                    }
                }
                
                // Add Category Card (hide when reordering)
                if !isReordering {
                    addCategoryCard
                }
                
                // Global Categories Section
                if !globalCategories.isEmpty {
                    sectionHeader("Global Categories", icon: "globe")
                    ForEach(Array(globalCategories.enumerated()), id: \.element.id) { index, category in
                        CategoryCard(
                            category: category,
                            isReordering: isReordering,
                            index: index,
                            totalCount: globalCategories.count,
                            onMoveUp: { moveCategoryInList(globalCategories, at: index, direction: -1) },
                            onMoveDown: { moveCategoryInList(globalCategories, at: index, direction: 1) }
                        )
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
                        ForEach(Array(eventCategories.enumerated()), id: \.element.id) { index, category in
                            CategoryCard(
                                category: category,
                                isReordering: isReordering,
                                index: index,
                                totalCount: eventCategories.count,
                                onMoveUp: { moveCategoryInList(eventCategories, at: index, direction: -1) },
                                onMoveDown: { moveCategoryInList(eventCategories, at: index, direction: 1) }
                            )
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
    
    private func moveCategoryInList(_ list: [Category], at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < list.count else { return }
        
        // Get the indices in the main categories array
        guard let sourceIdx = dataStore.categories.firstIndex(where: { $0.id == list[index].id }),
              let destIdx = dataStore.categories.firstIndex(where: { $0.id == list[newIndex].id }) else { return }
        
        // Swap the order values
        withAnimation(.spring(response: 0.3)) {
            var cat1 = dataStore.categories[sourceIdx]
            var cat2 = dataStore.categories[destIdx]
            let tempOrder = cat1.order
            cat1.order = cat2.order
            cat2.order = tempOrder
            dataStore.updateCategory(cat1)
            dataStore.updateCategory(cat2)
        }
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
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                Text("Add Category")
                    .font(.headline)
                    .foregroundColor(.gray)
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
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: showingAddCategory ? [] : [8, 4]))
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
    var isReordering: Bool = false
    var index: Int = 0
    var totalCount: Int = 1
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    
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
            
            if isReordering {
                // Reorder buttons
                VStack(spacing: 8) {
                    Button(action: { onMoveUp?() }) {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(index > 0 ? .white : .gray.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(index > 0 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(index == 0)
                    
                    Button(action: { onMoveDown?() }) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(index < totalCount - 1 ? .white : .gray.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(index < totalCount - 1 ? Color(hex: "#6366f1") : Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(index == totalCount - 1)
                }
            } else {
                // Delete button
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                }
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

// MARK: - Team Voice Settings View

struct TeamVoiceSettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var speechService = SpeechService.shared
    
    let event: TeamEvent
    
    @State private var selectedVoice: Voice?
    @State private var voiceRate: Float = 0.5
    @State private var voicePitch: Float = 1.0
    @State private var voiceVolume: Float = 1.0
    @State private var selectedVoiceIdentifier: String? = nil
    @State private var voiceName: String = ""
    @State private var isCreatingNew: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header info
                        VStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.largeTitle)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Announcer Voice")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                            
                            Text("Assign a voice to \(event.name)'s lineup")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Available voices selection
                        availableVoicesCard
                        
                        // Voice settings (show when editing or creating)
                        if selectedVoice != nil || isCreatingNew {
                            voiceConfigCard
                            
                            // Preview button
                            previewButton
                        }
                        
                        // Info text
                        Text("Players added to this lineup will use this voice for announcements.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechService.stop()
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVoiceSettings()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color(hex: "#6366f1"))
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    // MARK: - Available Voices Card
    
    private var availableVoicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Voice", systemImage: "person.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // No voice option
            Button(action: {
                selectedVoice = nil
                isCreatingNew = false
            }) {
                HStack {
                    Image(systemName: "speaker.slash")
                        .font(.caption)
                    Text("No Voice")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if selectedVoice == nil && !isCreatingNew {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "#22c55e"))
                    }
                }
                .foregroundColor(selectedVoice == nil && !isCreatingNew ? .white : .gray)
                .padding(12)
                .background(
                    selectedVoice == nil && !isCreatingNew ?
                    Color(hex: "#22c55e").opacity(0.2) :
                    Color.white.opacity(0.08)
                )
                .cornerRadius(10)
            }
            
            // Existing voices
            ForEach(dataStore.voices) { voice in
                Button(action: {
                    selectVoice(voice)
                }) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                        Text(voice.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if selectedVoice?.id == voice.id && !isCreatingNew {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "#22c55e"))
                        }
                    }
                    .foregroundColor(selectedVoice?.id == voice.id && !isCreatingNew ? .white : .gray)
                    .padding(12)
                    .background(
                        selectedVoice?.id == voice.id && !isCreatingNew ?
                        Color(hex: "#6366f1").opacity(0.3) :
                        Color.white.opacity(0.08)
                    )
                    .cornerRadius(10)
                }
            }
            
            // Create new voice option
            Button(action: {
                isCreatingNew = true
                selectedVoice = nil
                voiceName = "New Voice"
                voiceRate = 0.5
                voicePitch = 1.0
                voiceVolume = 1.0
                selectedVoiceIdentifier = nil
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text("Create New Voice")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if isCreatingNew {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "#22c55e"))
                    }
                }
                .foregroundColor(isCreatingNew ? .white : Color(hex: "#8b5cf6"))
                .padding(12)
                .background(
                    isCreatingNew ?
                    Color(hex: "#8b5cf6").opacity(0.3) :
                    Color(hex: "#8b5cf6").opacity(0.1)
                )
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Voice Config Card
    
    private var voiceConfigCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(isCreatingNew ? "New Voice Settings" : "Voice Settings", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            // Voice name (only for new voices)
            if isCreatingNew {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Name")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Enter voice name", text: $voiceName)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
            }
            
            // System voice selection
            VStack(alignment: .leading, spacing: 8) {
                Text("System Voice")
                    .font(.caption)
                    .foregroundColor(.gray)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Default announcer option
                        Button(action: { selectedVoiceIdentifier = nil }) {
                            VStack(spacing: 2) {
                                Text("Announcer")
                                    .font(.caption2.weight(.medium))
                                Text("(Default)")
                                    .font(.caption2)
                            }
                            .foregroundColor(selectedVoiceIdentifier == nil ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedVoiceIdentifier == nil ?
                                Color(hex: "#22c55e") :
                                Color.white.opacity(0.1)
                            )
                            .cornerRadius(6)
                        }
                        
                        ForEach(speechService.availableVoices.prefix(10), id: \.identifier) { voice in
                            Button(action: { selectedVoiceIdentifier = voice.identifier }) {
                                Text(voice.name.replacingOccurrences(of: " (Enhanced)", with: ""))
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(selectedVoiceIdentifier == voice.identifier ? .white : .gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedVoiceIdentifier == voice.identifier ?
                                        Color(hex: "#6366f1") :
                                        Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            // Speed slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", voiceRate * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                }
                Slider(value: $voiceRate, in: 0...1)
                    .tint(Color(hex: "#6366f1"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            // Pitch slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.1f", voicePitch))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                }
                Slider(value: $voicePitch, in: 0.5...2.0)
                    .tint(Color(hex: "#8b5cf6"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            // Volume slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.0f%%", voiceVolume * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                }
                Slider(value: $voiceVolume, in: 0...1)
                    .tint(Color(hex: "#ec4899"))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Preview Button
    
    private var previewButton: some View {
        Button(action: previewVoice) {
            HStack {
                Spacer()
                Image(systemName: speechService.isSpeaking ? "stop.fill" : "play.fill")
                Text(speechService.isSpeaking ? "Stop" : "Preview Voice")
                    .font(.headline)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#22c55e"), Color(hex: "#14b8a6")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    
    private func selectVoice(_ voice: Voice) {
        selectedVoice = voice
        isCreatingNew = false
        voiceName = voice.name
        voiceRate = voice.rate
        voicePitch = voice.pitch
        voiceVolume = voice.volume
        selectedVoiceIdentifier = voice.voiceIdentifier
    }
    
    private func loadCurrentSettings() {
        // Load the voice assigned to this team
        if let voice = dataStore.voiceForTeam(event.id) {
            selectVoice(voice)
        }
    }
    
    private func previewVoice() {
        if speechService.isSpeaking {
            speechService.stop()
        } else {
            let settings = VoiceOverSettings(
                enabled: true,
                text: "Now batting, number 7, Center Field, Mickey Mantle",
                voiceIdentifier: selectedVoiceIdentifier,
                rate: voiceRate,
                pitch: voicePitch,
                volume: voiceVolume,
                preDelay: 0,
                postDelay: 0
            )
            speechService.previewVoice(text: settings.text, settings: settings)
        }
    }
    
    private func saveVoiceSettings() {
        speechService.stop()
        
        if isCreatingNew {
            // Create a new voice and assign it to the team
            let newVoice = Voice(
                name: voiceName.isEmpty ? "New Voice" : voiceName,
                voiceIdentifier: selectedVoiceIdentifier,
                rate: voiceRate,
                pitch: voicePitch,
                volume: voiceVolume,
                preDelay: 0,
                postDelay: 0.5
            )
            dataStore.addVoice(newVoice)
            dataStore.assignVoiceToTeam(voiceID: newVoice.id, teamID: event.id)
        } else if let voice = selectedVoice {
            // Update existing voice settings
            var updatedVoice = voice
            updatedVoice.voiceIdentifier = selectedVoiceIdentifier
            updatedVoice.rate = voiceRate
            updatedVoice.pitch = voicePitch
            updatedVoice.volume = voiceVolume
            dataStore.updateVoice(updatedVoice)
            dataStore.assignVoiceToTeam(voiceID: voice.id, teamID: event.id)
        } else {
            // No voice selected - remove voice assignment
            dataStore.assignVoiceToTeam(voiceID: nil, teamID: event.id)
        }
        
        dismiss()
    }
}

#Preview {
    ManageView()
        .environmentObject(DataStore())
}
