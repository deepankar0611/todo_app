import SwiftUI
import FirebaseCore
import FirebaseFirestore

// Firebase configuration in your AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// Task Model
struct Task: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var priorityColorName: String // Store color as string for Firestore compatibility
    
    var priorityColor: Color {
        switch priorityColorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        default: return .blue
        }
    }
    
    init(id: String = UUID().uuidString, title: String, description: String, isCompleted: Bool, priorityColor: Color) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        
        // Convert Color to string
        if priorityColor == Color.red {
            self.priorityColorName = "red"
        } else if priorityColor == Color.orange {
            self.priorityColorName = "orange"
        } else if priorityColor == Color.green {
            self.priorityColorName = "green"
        } else {
            self.priorityColorName = "blue"
        }
    }
    
    // Create from Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let isCompleted = data["isCompleted"] as? Bool,
              let priorityColorName = data["priorityColorName"] as? String else {
            return nil
        }
        
        self.id = document.documentID
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priorityColorName = priorityColorName
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "title": title,
            "description": description,
            "isCompleted": isCompleted,
            "priorityColorName": priorityColorName
        ]
    }
    
    static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.id == rhs.id
    }
}

// Observable Task Store with Firebase integration
class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        fetchTasks()
    }
    
    deinit {
        // Remove listener when store is deallocated
        listenerRegistration?.remove()
    }
    
    func fetchTasks() {
        isLoading = true
        errorMessage = nil
        
        // Set up a listener for real-time updates
        listenerRegistration = db.collection("tasks")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Failed to fetch tasks: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.tasks = []
                    self.isLoading = false
                    return
                }
                
                self.tasks = documents.compactMap { document in
                    return Task(document: document)
                }
                
                self.isLoading = false
            }
    }
    
    func addTask(_ task: Task) {
        isLoading = true
        errorMessage = nil
        
        db.collection("tasks").document(task.id).setData(task.toDictionary()) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Failed to add task: \(error.localizedDescription)"
            }
        }
    }
    
    func toggleTask(_ id: String) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let task = tasks[index]
            _ = Task(
                id: task.id,
                title: task.title,
                description: task.description,
                isCompleted: !task.isCompleted,
                priorityColor: task.priorityColor
            )
            
            db.collection("tasks").document(id).updateData([
                "isCompleted": !task.isCompleted
            ]) { [weak self] error in
                if let error = error, let self = self {
                    self.errorMessage = "Failed to update task: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteTask(_ id: String) {
        db.collection("tasks").document(id).delete { [weak self] error in
            if let error = error, let self = self {
                self.errorMessage = "Failed to delete task: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteTasks(at offsets: IndexSet) {
        // Get the task IDs to delete
        let tasksToDelete = offsets.map { tasks[$0] }
        
        // Delete each task from Firestore
        for task in tasksToDelete {
            deleteTask(task.id)
        }
    }
    
    func moveTasks(from source: IndexSet, to destination: Int) {
        // Note: For simplicity, this implementation doesn't update order in Firestore
        // You would need to add an 'order' field to your tasks and update it
        tasks.move(fromOffsets: source, toOffset: destination)
    }
}

// Main Todo View
struct TodoView: View {
    @StateObject private var taskStore = TaskStore()
    @State private var isEditing = false
    @State private var showingAddTask = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("< Back")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .onTapGesture {
                                // Handle back navigation
                            }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Text("To-Do List")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Task List
                    if taskStore.isLoading && taskStore.tasks.isEmpty {
                        ProgressView("Loading tasks...")
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(taskStore.tasks) { task in
                                TaskRow(task: task,
                                       toggleTask: { taskStore.toggleTask(task.id) },
                                       deleteTask: { taskStore.deleteTask(task.id) })
                                    .listRowBackground(Color.white)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 4)
                            }
                            .onDelete(perform: isEditing ? taskStore.deleteTasks : nil)
                            .onMove(perform: isEditing ? taskStore.moveTasks : nil)
                        }
                        .listStyle(PlainListStyle())
                        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
                        .overlay(
                            Group {
                                if taskStore.tasks.isEmpty && !taskStore.isLoading {
                                    Text("No tasks yet. Add some!")
                                        .foregroundColor(.gray)
                                }
                            }
                        )
                    }
                    
                    // Error message
                    if let errorMessage = taskStore.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isEditing.toggle() }) {
                            Text(isEditing ? "Done" : "Edit")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Floating "+" Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(taskStore: taskStore, showingAddTask: $showingAddTask)
            }
        }
    }
}

// Custom Task Row
struct TaskRow: View {
    let task: Task
    let toggleTask: () -> Void
    let deleteTask: () -> Void

    var body: some View {
        HStack {
            // Priority Dot
            Circle()
                .fill(task.priorityColor)
                .frame(width: 10, height: 10)
                .padding(.trailing, 8)

            // Completion Toggle
            Button(action: toggleTask) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())

            // Task Details
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .foregroundColor(.primary)
                    .font(.headline)
                    .strikethrough(task.isCompleted, color: .gray)
                Text(task.description)
                    .foregroundColor(.gray)
                    .font(.caption)
                    .strikethrough(task.isCompleted, color: .gray)
            }

            Spacer()

            // Delete Button
            Button(action: deleteTask) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .id("\(task.id)-\(task.isCompleted)")
    }
}

// Add Task View
struct AddTaskView: View {
    @ObservedObject var taskStore: TaskStore
    @Binding var showingAddTask: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var priority: Color = .blue
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                        .textFieldStyle(PlainTextFieldStyle())
                    TextField("Description", text: $description)
                        .textFieldStyle(PlainTextFieldStyle())
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(Color.green)
                        Text("Medium").tag(Color.orange)
                        Text("High").tag(Color.red)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                            let newTask = Task(
                                title: title,
                                description: description.isEmpty ? "No description" : description,
                                isCompleted: false,
                                priorityColor: priority
                            )
                            taskStore.addTask(newTask)
                            dismiss()
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// App Entry Point with FirebaseApp configuration

#Preview {
    TodoView()
}
