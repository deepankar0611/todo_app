import SwiftUI
import FirebaseCore
import FirebaseFirestore

// Firebase configuration in your AppDelegate (unchanged)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// Task Model (unchanged)
struct Task: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var priorityColorName: String
    
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

// Observable Task Store with Firebase integration (unchanged)
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
        listenerRegistration?.remove()
    }
    
    func fetchTasks() {
        isLoading = true
        errorMessage = nil
        
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
                
                self.tasks = documents.compactMap { Task(document: $0) }
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
    
    func updateTask(_ task: Task) {
        isLoading = true
        errorMessage = nil
        
        db.collection("tasks").document(task.id).updateData(task.toDictionary()) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Failed to update task: \(error.localizedDescription)"
            }
        }
    }
    
    func toggleTask(_ id: String) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let task = tasks[index]
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
        let tasksToDelete = offsets.map { tasks[$0] }
        for task in tasksToDelete {
            deleteTask(task.id)
        }
    }
    
    func moveTasks(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
    }
}

// Main Todo View (Updated)
struct TodoView: View {
    @StateObject private var taskStore = TaskStore()
    @State private var isEditing = false
    @State private var showingAddTask = false
    @State private var showingEditTask = false
    @State private var taskToEdit: Task?  // Optional task to edit

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
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

                    if taskStore.isLoading && taskStore.tasks.isEmpty {
                        ProgressView("Loading tasks...")
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(taskStore.tasks) { task in
                                TaskRow(task: task,
                                        toggleTask: { taskStore.toggleTask(task.id) },
                                        editTask: {
                                            print("Setting taskToEdit: \(task.title)")  // Debug
                                            taskToEdit = task
                                            DispatchQueue.main.async {
                                                showingEditTask = true  // Ensure state update
                                            }
                                        },
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
            // Simplified sheet with item binding
            .sheet(item: Binding<Task?>(
                get: { taskToEdit },
                set: { taskToEdit = $0 }
            )) { task in
                EditTaskView(taskStore: taskStore, task: task, showingEditTask: $showingEditTask)
                    .onAppear {
                        print("EditTaskView appeared for: \(task.title)")  // Debug
                    }
            }
        }
    }
}

// Custom Task Row (unchanged)
struct TaskRow: View {
    let task: Task
    let toggleTask: () -> Void
    let editTask: () -> Void
    let deleteTask: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(task.priorityColor)
                .frame(width: 10, height: 10)
                .padding(.trailing, 8)

            Button(action: toggleTask) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())

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

            Button(action: editTask) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)

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

// Add Task View (unchanged)
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

// Edit Task View (unchanged)
struct EditTaskView: View {
    @ObservedObject var taskStore: TaskStore
    let task: Task
    @Binding var showingEditTask: Bool
    @State private var title: String
    @State private var description: String
    @State private var priority: Color
    @Environment(\.dismiss) var dismiss

    init(taskStore: TaskStore, task: Task, showingEditTask: Binding<Bool>) {
        self.taskStore = taskStore
        self.task = task
        self._showingEditTask = showingEditTask
        self._title = State(initialValue: task.title)
        self._description = State(initialValue: task.description)
        self._priority = State(initialValue: task.priorityColor)
    }

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
            .navigationTitle("Edit Task")
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
                            let updatedTask = Task(
                                id: task.id,
                                title: title,
                                description: description.isEmpty ? "No description" : description,
                                isCompleted: task.isCompleted,
                                priorityColor: priority
                            )
                            taskStore.updateTask(updatedTask)
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

#Preview {
    TodoView()
}
