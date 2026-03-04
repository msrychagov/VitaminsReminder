import SwiftUI

struct VitaminDraft: Equatable, Hashable {
    var name: String = ""
    var type: String = ""
    var dose: String = ""
    var intake: IntakeMoment? = nil
    var notes: String = ""
    var catalogID: Int? = nil
    var catalogDefaultUnit: String? = nil
    var catalogInteractionText: String? = nil
    var catalogCompatibilityText: String? = nil
    var catalogContraindicationsText: String? = nil
    var catalogDefaultCondition: String? = nil
    var interactionTextOverride: String? = nil
    var compatibilityTextOverride: String? = nil
    var contraindicationsTextOverride: String? = nil
    var includeDose: Bool = true
    var includeFrequency: Bool = true
    var includeInteraction: Bool = true
    var includeCompatibility: Bool = true
    var includeCondition: Bool = true
    var includeContraindications: Bool = true
    var intakeTimes: [String] = []
    var weekdays: [Weekday] = Weekday.allCases
    var courseStartDate: Date = Date().startOfDayUniversal
    var courseEndDate: Date? = nil
}

enum IntakeMoment: String, CaseIterable, Identifiable {
    case before = "До еды"
    case after = "После еды"
    case during = "Во время\nеды"
    case any = "Неважно"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .before: return "plateUnselected"
        case .after: return "forkUnselected"
        case .during: return "kneeUnselected"
        case .any: return "markMagnifierUnselected"
        }
    }

    var selectedIconName: String {
        switch self {
        case .before: return "plateSelected"
        case .after: return "forkSelected"
        case .during: return "kneeSelected"
        case .any: return "markMahnifierSelected"
        }
    }

    var apiCondition: String {
        switch self {
        case .before: return "before_meal"
        case .after: return "after_meal"
        case .during: return "during_meal"
        case .any: return "any"
        }
    }
}

struct AddVitaminView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab
    let onNext: (VitaminDraft) -> Void
    let onTabRequested: ((AppTab) -> Void)?
    private let repository: VitaminRepository

    @State private var draft: VitaminDraft
    @State private var isVitaminTypePickerPresented = false
    @State private var isCatalogSearchPresented = false
    @State private var pendingVitaminTypeIndex = 0
    @State private var doseAmountText: String
    @State private var catalogItems: [VitaminCatalogItem] = []
    @State private var selectedCatalogID: Int?
    @State private var catalogSearchText = ""
    @State private var isCatalogLoading = false
    @State private var catalogLoadErrorMessage: String?
    @State private var didAttemptCatalogLoad = false
    @FocusState private var isCatalogSearchFieldFocused: Bool
    @State private var isCatalogKeyboardVisible = false
    @State private var isAlertPresented = false
    @State private var alertTitle = "Заполните обязательные поля"
    @State private var alertMessage = "Пожалуйста, заполните всю информацию, кроме поля «Примечание»."
    private let blue = Color(hex: "0E75F2")
    private let lightField = Color(red: 248/255, green: 250/255, blue: 251/255)
    private let wheelRepeatCount = 200
    private let vitaminTypes = [
        "Таблетки",
        "Капсулы",
        "Капли",
        "Порошок",
        "Жидкость",
        "Жевательные таблетки",
        "Ампулы",
        "Спрей",
        "Уколы"
    ]
    private var wheelItemCount: Int {
        vitaminTypes.count * wheelRepeatCount
    }
    private var wheelMiddleStartIndex: Int {
        (wheelRepeatCount / 2) * vitaminTypes.count
    }
    private var normalizedPendingTypeIndex: Int {
        guard !vitaminTypes.isEmpty else { return 0 }
        let remainder = pendingVitaminTypeIndex % vitaminTypes.count
        return remainder >= 0 ? remainder : remainder + vitaminTypes.count
    }
    private var doseAmountValue: Int? {
        Int(doseAmountText)
    }
    private var doseUnitTitle: String {
        doseUnit(for: draft.type, quantity: doseAmountValue)
    }
    private var isRequiredFormFilled: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !draft.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !doseAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && draft.intake != nil
    }

    init(
        selectedTab: Binding<AppTab>,
        onNext: @escaping (VitaminDraft) -> Void,
        onTabRequested: ((AppTab) -> Void)? = nil,
        initialDraft: VitaminDraft? = nil,
        repository: VitaminRepository = VitaminRepository()
    ) {
        let seedDraft = initialDraft ?? VitaminDraft()
        _selectedTab = selectedTab
        _draft = State(initialValue: seedDraft)
        _doseAmountText = State(initialValue: Self.extractDoseAmount(from: seedDraft.dose))
        _selectedCatalogID = State(initialValue: seedDraft.catalogID)
        self.onNext = onNext
        self.onTabRequested = onTabRequested
        self.repository = repository
    }

    private static func extractDoseAmount(from dose: String) -> String {
        dose.filter(\.isNumber)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "EFF6FF"), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        progressIndicators
                            .padding(.top, 18)
                            .padding(.horizontal, 30)

                        titleField
                            .padding(.bottom, 9) // 1.5x spacing to next element

                        vitaminTypeButton
                            .padding(.horizontal, 30)

                        doseBlock
                            .padding(.horizontal, 30)

                        intakeGrid
                            .padding(.top, 36) // reduced spacing to dose block
                            .padding(.horizontal, 30)

                        notesField
                            .padding(.top, 18) // double gap from cells
                            .padding(.horizontal, 30)

                        buttonsRow
                            .padding(.top, 28)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 28)
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)

                tabBarOverlay
            }
        }
        .overlay {
            catalogSearchOverlay
                .zIndex(12)
            if isVitaminTypePickerPresented {
                vitaminTypePickerOverlay
                    .zIndex(10)
            }
        }
        .task {
            await loadCatalogIfNeeded()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .simultaneousGesture(TapGesture().onEnded {
            if isVitaminTypePickerPresented || isCatalogSearchPresented {
                return
            }
            UIApplication.shared.endEditing()
        })
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            if isCatalogSearchPresented {
                isCatalogKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isCatalogKeyboardVisible = false
        }
        .alert(alertTitle, isPresented: $isAlertPresented) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Sections
    private var progressIndicators: some View {
        StepProgressView(filledSegments: 1)
            .frame(maxWidth: .infinity)
    }

    private var conicGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "0773F1"), location: 0.0),
                .init(color: .white, location: 0.55),
                .init(color: Color(hex: "D1FFBA"), location: 0.72),
                .init(color: Color(hex: "0773F1"), location: 0.96),
                .init(color: .white, location: 1.0)
            ]),
            center: .init(x: 0.9037, y: -1.4375),
            angle: .degrees(205)
        )
    }

    private var titleField: some View {
        Button {
            presentCatalogSearch()
        } label: {
            HStack(spacing: 12) {
                Image("pen")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 24, height: 24)

                Text(draft.name.isEmpty ? "Название" : draft.name)
                    .font(.custom("Commissioner-Bold", size: 32))
                    .foregroundColor(draft.name.isEmpty ? .black : Color(hex: "3B3B3B"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if isCatalogLoading {
                    Spacer(minLength: 0)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(hex: "0773F1"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
    }

    private var filteredCatalogItems: [VitaminCatalogItem] {
        let query = normalizedSearchValue(catalogSearchText)
        let base = catalogItems.sorted {
            $0.resolvedName.localizedCaseInsensitiveCompare($1.resolvedName) == .orderedAscending
        }

        guard !query.isEmpty else {
            return base
        }

        let ranked = base.compactMap { item -> (item: VitaminCatalogItem, score: Int)? in
            let name = normalizedSearchValue(item.resolvedName)
            let code = normalizedSearchValue(item.code ?? "")

            let nameScore = fuzzyScore(query: query, candidate: name)
            let codeScore = fuzzyScore(query: query, candidate: code).map { $0 + 8 }
            let best = [nameScore, codeScore].compactMap { $0 }.min()

            guard let best else { return nil }
            return (item, best)
        }

        return ranked
            .sorted {
                if $0.score == $1.score {
                    return $0.item.resolvedName.localizedCaseInsensitiveCompare($1.item.resolvedName) == .orderedAscending
                }
                return $0.score < $1.score
            }
            .map { $0.item }
    }

    private var catalogSearchOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(isCatalogSearchPresented ? 0.35 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if isCatalogKeyboardVisible || isCatalogSearchFieldFocused {
                            dismissCatalogKeyboard()
                            return
                        }
                        if isCatalogSearchPresented {
                            dismissCatalogSearch()
                        }
                    }

                catalogSearchSheet
                    .offset(y: isCatalogSearchPresented ? 0 : proxy.size.height + 120)
            }
            .animation(.easeInOut(duration: 0.24), value: isCatalogSearchPresented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(isCatalogSearchPresented)
    }

    private var catalogSearchSheet: some View {
        GeometryReader { proxy in
            let sheetHeight = proxy.size.height * 0.72

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 60, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "1E7BF3"))
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 34, height: 34)

                    TextField(
                        "",
                        text: $catalogSearchText,
                        prompt: Text("Поиск витамина").foregroundColor(Color(hex: "6B6B6B"))
                    )
                    .focused($isCatalogSearchFieldFocused)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(Color(hex: "1F1F1F"))

                    Button {
                        catalogSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "A7A9AE"))
                    }
                    .opacity(catalogSearchText.isEmpty ? 0 : 1)
                    .disabled(catalogSearchText.isEmpty)
                }
                .padding(.horizontal, 10)
                .frame(height: 52)
                .background(Color(hex: "D8DCE1"))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                Group {
                    if isCatalogLoading && catalogItems.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color(hex: "0773F1"))
                            Text("Загрузка витаминов...")
                                .font(.custom("Commissioner-Medium", size: 14))
                                .foregroundColor(Color(hex: "8C8C8C"))
                            Spacer()
                        }
                    } else if let catalogLoadErrorMessage, catalogItems.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Text(catalogLoadErrorMessage)
                                .font(.custom("Commissioner-Medium", size: 14))
                                .foregroundColor(Color(hex: "8C8C8C"))
                                .multilineTextAlignment(.center)

                            Button("Повторить") {
                                Task { await loadCatalogIfNeeded(force: true) }
                            }
                            .font(.custom("Commissioner-SemiBold", size: 16))
                            .foregroundColor(Color(hex: "0773F1"))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                if filteredCatalogItems.isEmpty {
                                    Text("Ничего не найдено")
                                        .font(.custom("Commissioner-Medium", size: 16))
                                        .foregroundColor(Color(hex: "8C8C8C"))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 24)
                                } else {
                                    ForEach(filteredCatalogItems) { item in
                                        catalogRow(item)
                                        Divider()
                                            .background(Color(hex: "D4D7DD"))
                                    }
                                }
                            }
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !catalogSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !isCatalogLoading
                    && catalogLoadErrorMessage == nil
                    && filteredCatalogItems.isEmpty {
                    Button(action: selectCustomVitaminFromSearch) {
                        Text("Добавить свой")
                            .font(.custom("Commissioner-Bold", size: 20))
                            .foregroundColor(.white)
                            .frame(width: 240, height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "1E7BF3"), Color(hex: "A6C4DD")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.bottom, max(56, proxy.safeAreaInsets.bottom + 40))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: sheetHeight, alignment: .top)
            .background(
                TopRoundedRectangle(radius: 24)
                    .fill(Color(hex: "F4F5F7"))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func catalogRow(_ item: VitaminCatalogItem) -> some View {
        let isSelected = selectedCatalogID == item.id
            || normalizedSearchValue(draft.name) == normalizedSearchValue(item.resolvedName)

        return Button {
            if isCatalogKeyboardVisible {
                dismissCatalogKeyboard()
                return
            }
            selectCatalogItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text(item.resolvedName)
                        .font(.custom("Commissioner-SemiBold", size: 20))
                        .foregroundColor(Color(hex: "1C1C1C"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hex: "1E7BF3"))
                    }
                }

                Text(catalogSubtitle(for: item))
                    .font(.custom("Commissioner-Medium", size: 14))
                    .foregroundColor(Color(hex: "A2A4A9"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func catalogSubtitle(for item: VitaminCatalogItem) -> String {
        let normalized = item.resolvedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = normalized.split(separator: " ").first {
            return String(first)
        }
        return "Витамин"
    }

    private var vitaminTypeButton: some View {
        Button {
            UIApplication.shared.endEditing()
            isCatalogSearchFieldFocused = false
            isCatalogSearchPresented = false
            let selectedTypeIndex = vitaminTypes.firstIndex(of: draft.type) ?? 0
            pendingVitaminTypeIndex = wheelMiddleStartIndex + selectedTypeIndex
            withAnimation(.easeInOut(duration: 0.2)) {
                isVitaminTypePickerPresented = true
            }
        } label: {
            HStack {
                Text(draft.type.isEmpty ? "Вид витамина" : draft.type)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(.white)
                Spacer()
                Image("chevronWhite")
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(blue)
            .cornerRadius(14)
        }
        .frame(maxWidth: 343)
    }

    private var vitaminTypePickerOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    commitVitaminTypeAndDismissPicker()
                }

            vitaminTypePickerSheet
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var vitaminTypePickerSheet: some View {
        GeometryReader { proxy in
            let sheetHeight = proxy.size.height * 0.31

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 60, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                HStack {
                    Spacer()
                    Button("Готово") {
                        commitVitaminTypeAndDismissPicker()
                    }
                    .buttonStyle(.plain)
                    .font(.custom("Commissioner-SemiBold", size: 18))
                    .foregroundColor(.white)
                    .padding(.trailing, 18)
                    .padding(.bottom, 2)
                    .offset(y: -8)
                }

                if !vitaminTypes.isEmpty {
                    Picker("", selection: $pendingVitaminTypeIndex) {
                        ForEach(0..<wheelItemCount, id: \.self) { index in
                            Text(vitaminTypes[index % vitaminTypes.count])
                                .font(.custom("Commissioner-Regular", size: 24))
                                .foregroundColor(.white)
                                .tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .padding(.horizontal, 8)
                    .onChange(of: pendingVitaminTypeIndex) { _ in
                        recenterVitaminTypeWheelIfNeeded()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: sheetHeight, alignment: .top)
            .background(
                TopRoundedRectangle(radius: 34)
                    .fill(Color(hex: "808080").opacity(0.96))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func commitVitaminTypeAndDismissPicker() {
        if !vitaminTypes.isEmpty {
            draft.type = vitaminTypes[normalizedPendingTypeIndex]
            rebuildDraftDose()
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isVitaminTypePickerPresented = false
        }
    }

    private func recenterVitaminTypeWheelIfNeeded() {
        guard !vitaminTypes.isEmpty else { return }
        let oneLoop = vitaminTypes.count
        let lowerBound = oneLoop * 2
        let upperBound = wheelItemCount - oneLoop * 2

        if pendingVitaminTypeIndex < lowerBound || pendingVitaminTypeIndex > upperBound {
            pendingVitaminTypeIndex = wheelMiddleStartIndex + normalizedPendingTypeIndex
        }
    }

    private func loadCatalogIfNeeded(force: Bool = false) async {
        if isCatalogLoading { return }
        if didAttemptCatalogLoad && !force { return }

        await MainActor.run {
            isCatalogLoading = true
            catalogLoadErrorMessage = nil
            didAttemptCatalogLoad = true
        }

        do {
            let items = try await repository.fetchCatalog()
            await MainActor.run {
                catalogItems = items
                isCatalogLoading = false
            }
        } catch {
            await MainActor.run {
                catalogItems = []
                isCatalogLoading = false
                catalogLoadErrorMessage = "Не удалось загрузить каталог витаминов"
            }
        }
    }

    private func presentCatalogSearch() {
        UIApplication.shared.endEditing()
        isCatalogSearchFieldFocused = false
        isVitaminTypePickerPresented = false
        catalogSearchText = draft.name

        withAnimation(.easeInOut(duration: 0.2)) {
            isCatalogSearchPresented = true
        }

        Task { await loadCatalogIfNeeded() }
    }

    private func dismissCatalogSearch() {
        dismissCatalogKeyboard()
        withAnimation(.easeInOut(duration: 0.2)) {
            isCatalogSearchPresented = false
        }
    }

    private func dismissCatalogKeyboard() {
        isCatalogSearchFieldFocused = false
        isCatalogKeyboardVisible = false
        UIApplication.shared.endEditing()
    }

    private func selectCatalogItem(_ item: VitaminCatalogItem) {
        draft.name = item.resolvedName
        draft.catalogID = item.id
        draft.catalogDefaultUnit = item.defaultUnit
        draft.catalogInteractionText = item.interactionText
        draft.catalogCompatibilityText = item.compatibilityText
        draft.catalogContraindicationsText = item.contraindicationsText
        draft.catalogDefaultCondition = item.defaultCondition
        if draft.intake == nil, let defaultIntake = intakeMoment(from: item.defaultCondition) {
            draft.intake = defaultIntake
        }
        selectedCatalogID = item.id
        dismissCatalogSearch()
    }

    private func selectCustomVitaminFromSearch() {
        let customName = catalogSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customName.isEmpty else {
            presentAlert(
                title: "Нужно выбрать витамин",
                message: "Введите название витамина в поле поиска или выберите его из списка."
            )
            return
        }

        draft.name = customName
        draft.catalogID = nil
        draft.catalogDefaultUnit = nil
        draft.catalogInteractionText = nil
        draft.catalogCompatibilityText = nil
        draft.catalogContraindicationsText = nil
        draft.catalogDefaultCondition = nil
        selectedCatalogID = nil
        dismissCatalogSearch()
    }

    private func intakeMoment(from apiCondition: String?) -> IntakeMoment? {
        switch apiCondition?.lowercased() {
        case "before_meal":
            return .before
        case "after_meal":
            return .after
        case "during_meal":
            return .during
        case "any":
            return .any
        default:
            return nil
        }
    }

    private func handleNextTap() {
        guard isRequiredFormFilled else {
            presentAlert(
                title: "Заполните обязательные поля",
                message: "Пожалуйста, заполните всю информацию, кроме поля «Примечание»."
            )
            return
        }
        onNext(draft)
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isAlertPresented = true
    }

    private func normalizedSearchValue(_ value: String) -> String {
        let lowered = value.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "ru_RU"))

        let cleaned = lowered.replacingOccurrences(
            of: "[^a-zа-я0-9]+",
            with: " ",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fuzzyScore(query: String, candidate: String) -> Int? {
        guard !query.isEmpty, !candidate.isEmpty else { return nil }
        if candidate == query { return 0 }

        let tokens = candidate.split(separator: " ").map(String.init)
        var best = Int.max

        if candidate.hasPrefix(query) {
            best = min(best, 8 + max(0, candidate.count - query.count))
        }
        if candidate.contains(query) {
            best = min(best, 20 + max(0, candidate.count - query.count))
        }

        for token in tokens {
            if token == query {
                best = min(best, 6)
            }
            if token.hasPrefix(query) {
                best = min(best, 12 + max(0, token.count - query.count))
            }
            if token.contains(query) {
                best = min(best, 26 + max(0, token.count - query.count))
            }
        }

        if isSubsequence(query, in: candidate) {
            best = min(best, 45 + max(0, candidate.count - query.count))
        }

        let threshold = max(1, query.count / 3)

        let candidateDistance = levenshteinDistance(query, candidate)
        if candidateDistance <= threshold + 1 {
            best = min(best, 70 + candidateDistance * 10 + abs(candidate.count - query.count))
        }

        for token in tokens {
            let distance = levenshteinDistance(query, token)
            if distance <= threshold {
                best = min(best, 60 + distance * 10 + abs(token.count - query.count))
            }
        }

        return best == Int.max ? nil : best
    }

    private func isSubsequence(_ query: String, in candidate: String) -> Bool {
        guard !query.isEmpty else { return true }

        var queryIndex = query.startIndex
        for char in candidate where queryIndex < query.endIndex {
            if char == query[queryIndex] {
                query.formIndex(after: &queryIndex)
            }
        }
        return queryIndex == query.endIndex
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)

        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = Array(repeating: 0, count: right.count + 1)

        for i in 0..<left.count {
            current[0] = i + 1

            for j in 0..<right.count {
                let cost = left[i] == right[j] ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + cost
                )
            }

            swap(&previous, &current)
        }

        return previous[right.count]
    }

    private var doseBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Разовая доза")
                .font(.custom("Commissioner-Medium", size: 12))
                .foregroundColor(Color(hex: "4A4A4A"))
                .padding(.leading, 24)

            HStack(spacing: 12) {
                TextField(
                    "",
                    text: Binding(
                        get: { doseAmountText },
                        set: { newValue in
                            doseAmountText = sanitizedDoseInput(newValue)
                            rebuildDraftDose()
                        }
                    ),
                    prompt: Text("Введите количество").foregroundColor(.white.opacity(0.65))
                )
                .keyboardType(.numberPad)
                .font(.custom("Commissioner-SemiBold", size: 18))
                .foregroundColor(.white)

                if !doseUnitTitle.isEmpty {
                    Text(doseUnitTitle)
                        .font(.custom("Commissioner-SemiBold", size: 18))
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize()
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .frame(height: 49)
            .frame(maxWidth: .infinity)
            .background(blue)
            .cornerRadius(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sanitizedDoseInput(_ raw: String) -> String {
        raw.filter { $0.isNumber }
    }

    private func rebuildDraftDose() {
        let trimmedAmount = doseAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAmount.isEmpty else {
            draft.dose = ""
            return
        }

        let unit = doseUnit(for: draft.type, quantity: Int(trimmedAmount))
        if unit.isEmpty {
            draft.dose = trimmedAmount
        } else {
            draft.dose = "\(trimmedAmount) \(unit)"
        }
    }

    private func doseUnit(for type: String, quantity: Int?) -> String {
        switch type.lowercased() {
        case "таблетки", "капсулы", "жевательные таблетки", "ампулы", "уколы":
            return "шт."
        case "порошок":
            return "г"
        case "жидкость":
            return "мл"
        case "капли":
            guard let quantity else { return "капли" }
            return russianPluralForm(
                for: quantity,
                one: "капля",
                few: "капли",
                many: "капель"
            )
        case "спрей":
            guard let quantity else { return "нажатия" }
            return russianPluralForm(
                for: quantity,
                one: "нажатие",
                few: "нажатия",
                many: "нажатий"
            )
        default:
            return ""
        }
    }

    private func russianPluralForm(for value: Int, one: String, few: String, many: String) -> String {
        let absolute = abs(value)
        let lastTwo = absolute % 100
        let last = absolute % 10

        if (11...14).contains(lastTwo) {
            return many
        }
        if last == 1 {
            return one
        }
        if (2...4).contains(last) {
            return few
        }
        return many
    }

    private var intakeGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(IntakeMoment.allCases) { moment in
                VStack(spacing: 10) {
                    intakeSquare(for: moment)
                    Text(moment.rawValue)
                        .font(.custom("Commissioner-Medium", size: 12))
                        .foregroundColor(Color(hex: "3B3B3B"))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func intakeSquare(for moment: IntakeMoment) -> some View {
        let isSelected = draft.intake == moment
        let size: CGSize = {
            switch moment {
            case .before: return CGSize(width: 32, height: 32)
            case .after: return CGSize(width: 16, height: 39)
            case .during: return CGSize(width: 26, height: 26)
            case .any: return CGSize(width: 30, height: 30)
            }
        }()

        let imageName = isSelected ? moment.selectedIconName : moment.iconName

        return Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .shadow(color: .clear, radius: 0)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: 74.7, height: 69)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? blue : Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.2), lineWidth: 0.6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    draft.intake = moment
                }
            }
    }

    private var notesField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(lightField)
                .frame(height: 57)
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1)

            TextField(
                "",
                text: $draft.notes,
                prompt: Text("Примечание").foregroundColor(Color(hex: "8093A6"))
            )
            .font(.custom("Commissioner-Medium", size: 16))
            .foregroundColor(Color(hex: "3B3B3B"))
            .padding(.horizontal, 18)
            .frame(height: 57, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    private var buttonsRow: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
                Text("Назад")
                    .font(.custom("Commissioner-Bold", size: 20))
                    .foregroundColor(blue)
                    .frame(width: 155, height: 52)
                    .background(Color.white)
                    .overlay(borderGradientStroke)
                    .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
            }

            Spacer()

            Button(action: { handleNextTap() }) {
                Text("Далее")
                    .font(.custom("Commissioner-Bold", size: 20))
                    .foregroundColor(.white)
                    .frame(width: 155, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1E7BF3"), Color(hex: "A6C4DD")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var borderGradientStroke: some View {
        RoundedRectangle(cornerRadius: 100)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color(red: 231/255, green: 240/255, blue: 255/255, opacity: 0.52),
                        Color(red: 136/255, green: 164/255, blue: 255/255, opacity: 1),
                        Color(red: 180/255, green: 210/255, blue: 255/255, opacity: 0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
    }

    private var tabBarOverlay: some View {
        HStack {
            Spacer(minLength: 0)
            AppTabBar(
                selectedTab: Binding(
                    get: { selectedTab },
                    set: { tab in
                        guard tab != selectedTab else { return }
                        UIApplication.shared.endEditing()
                        if onTabRequested == nil {
                            selectedTab = tab
                            dismiss()
                        }
                    }
                ),
                onSelect: { tab in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    guard let onTabRequested else { return }
                    UIApplication.shared.endEditing()
                    onTabRequested(tab)
                }
            )
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
        .padding(.horizontal, 0)
    }
}

// Placeholder for notification setup
struct NotificationSetupPlaceholderView: View {
    let draft: VitaminDraft

    var body: some View {
        let nameValue = draft.name.isEmpty ? "—" : draft.name
        let typeValue = draft.type.isEmpty ? "—" : draft.type
        let doseValue = draft.dose.isEmpty ? "—" : draft.dose
        let intakeValue = draft.intake?.rawValue ?? "—"
        let notesValue = draft.notes.isEmpty ? "—" : draft.notes

        VStack(spacing: 16) {
            Text("Настройка уведомлений")
                .font(.custom("Commissioner-Bold", size: 24))

            VStack(alignment: .leading, spacing: 8) {
                Text("Название: \(nameValue)")
                Text("Вид: \(typeValue)")
                Text("Доза: \(doseValue)")
                Text("Прием: \(intakeValue)")
                Text("Примечание: \(notesValue)")
            }
            .font(.custom("Commissioner-Medium", size: 16))
            .foregroundColor(Color(hex: "4A4A4A"))

            Text("Здесь будет логика выбора времени напоминаний и отправка запроса на сервер.")
                .font(.custom("Commissioner-Regular", size: 15))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(min(radius, rect.width / 2), rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}
