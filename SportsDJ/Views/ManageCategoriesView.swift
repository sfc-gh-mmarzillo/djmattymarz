import SwiftUI

struct ManageCategoriesView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var newCategoryName: String = ""
    @State private var newCategoryColor: String = "#007AFF"
    @State private var showingAddCategory = false
    
    let colorOptions = [
        "#007AFF", "#34C759", "#FF3B30", "#FF9500",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Add New Category") {
                    HStack {
                        TextField("Category name", text: $newCategoryName)
                        
                        Menu {
                            ForEach(colorOptions, id: \.self) { color in
                                Button(action: { newCategoryColor = color }) {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 20, height: 20)
                                        if newCategoryColor == color {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: newCategoryColor))
                                .frame(width: 24, height: 24)
                        }
                        
                        Button(action: addCategory) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newCategoryName.isEmpty)
                    }
                }
                
                Section("Existing Categories") {
                    if dataStore.categories.isEmpty {
                        Text("No categories yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(dataStore.categories) { category in
                            HStack {
                                Circle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: 16, height: 16)
                                Text(category.name)
                                Spacer()
                                let count = dataStore.buttons.filter { $0.categoryTags.contains(category.name) }.count
                                Text("\(count) buttons")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteCategories)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    func addCategory() {
        guard !newCategoryName.isEmpty else { return }
        let category = Category(name: newCategoryName, colorHex: newCategoryColor)
        dataStore.addCategory(category)
        newCategoryName = ""
    }
    
    func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            dataStore.deleteCategory(dataStore.categories[index])
        }
    }
}
