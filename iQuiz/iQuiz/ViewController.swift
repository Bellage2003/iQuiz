//
//  ViewController.swift
//  iQuiz
//
//  Created by 小戈 on 2024/5/3.
//

import UIKit
import Network

class NetworkManager {
    static let shared = NetworkManager()
    var quizzesURL: URL {
        if let urlString = UserDefaults.standard.string(forKey: "DataSourceURL"), let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://tednewardsandbox.site44.com/questions.json")!
    }

    func updateQuizzesURL(with urlString: String) {
        UserDefaults.standard.set(urlString, forKey: "DataSourceURL")
    }

    func fetchQuizzes(completion: @escaping (Result<[QuizTopic], Error>) -> Void) {
        print("Fetching quizzes from URL: \(quizzesURL.absoluteString)")
        URLSession.shared.dataTask(with: quizzesURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL or server error."])))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received."])))
                    return
                }

                do {
                    let quizzes = try JSONDecoder().decode([QuizTopic].self, from: data)
                    completion(.success(quizzes))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

struct QuizTopic: Codable {
    var icon: String?
    var title: String
    var description: String
    var questions: [Question]
    
    enum CodingKeys: String, CodingKey {
        case title, description = "desc", questions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        questions = try container.decode([Question].self, forKey: .questions)
        icon = QuizTopic.defaultIcon(for: title)
    }
    
    static func defaultIcon(for title: String) -> String {
        switch title {
        case "Science!":
            return "science_icon"
        case "Marvel Super Heroes":
            return "heroes_icon"
        case "Mathematics":
            return "math_icon"
        default:
            return "default_icon"
        }
    }
}

struct Question: Codable {
    var text: String
    var correctAnswer: String
    var answers: [String]
    
    enum CodingKeys: String, CodingKey {
        case text, answers, correctAnswer = "answer"
    }
}

class CustomTableViewCell: UITableViewCell {
    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    let descriptionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        setupConstraints()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with topic: QuizTopic) {
        iconImageView.image = UIImage(named: topic.icon ?? "default_photo")
        titleLabel.text = topic.title
        descriptionLabel.text = topic.description
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
    }
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var tableView: UITableView!
    var quizTopics = [QuizTopic]()
    var currentQuizIndex = 0
    var currentQuestionIndex = 0
    var correctAnswersCount = 0
    var selectedAnswerIndex: Int?

    let questionLabel = UILabel()
    let buttonsStackView = UIStackView()
    let submitButton = UIButton()
    let nextButton = UIButton()
    let backButton = UIButton()
    let resultLabel = UILabel()
    let networkMonitor = NWPathMonitor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "iQuiz"
        setupNetworkMonitoring()
        setupSwipeGestures()
        showSwipeHints()
        fetchQuizData()
        setupTableView()
        setupToolbar()
        setupQuestionUI()
    }
    
    func setupSwipeGestures() {
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .left
        view.addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .right
        view.addGestureRecognizer(swipeLeft)
    }

    @objc private func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .ended {
            print("Swiped right: Submit answer or go to next")
            if submitButton.isHidden {
                handleNext()
            } else {
                submitAnswer()
            }
        }
    }

    @objc private func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .ended {
            backToTopics()
            print("Swiped left: abandon quiz")
        }
    }
    
    private func showSwipeHints() {
        let swipeRightHint = UILabel(frame: CGRect(x: view.bounds.width - 160, y: view.bounds.height - 100, width: 150, height: 50))
        swipeRightHint.text = "Swipe Right ➡️\nSubmit/Next"
        swipeRightHint.numberOfLines = 0
        swipeRightHint.textAlignment = .right
        swipeRightHint.backgroundColor = UIColor.systemGray5
        swipeRightHint.layer.cornerRadius = 10
        swipeRightHint.clipsToBounds = true
        view.addSubview(swipeRightHint)

        let swipeLeftHint = UILabel(frame: CGRect(x: 10, y: view.bounds.height - 100, width: 150, height: 50))
        swipeLeftHint.text = "  Swipe Left ⬅️\n  Quit Quiz"
        swipeLeftHint.numberOfLines = 0
        swipeLeftHint.backgroundColor = UIColor.systemGray5
        swipeLeftHint.layer.cornerRadius = 10
        swipeLeftHint.clipsToBounds = true
        view.addSubview(swipeLeftHint)
    }

    
    func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("Internet connection is available.")
            } else {
                DispatchQueue.main.async {
                    self.showError(message: "No internet connection available.")
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    func setupTableView() {
        tableView = UITableView()
        tableView.frame = view.bounds
        tableView.register(CustomTableViewCell.self, forCellReuseIdentifier: "CustomTableViewCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.layoutIfNeeded()
        updateTableViewContentInset()
    }
    
    func updateTableViewContentInset() {
        let totalRowHeight = tableView.contentSize.height
        let availableHeight = tableView.bounds.size.height - tableView.safeAreaInsets.top - tableView.safeAreaInsets.bottom

        let insetTop = max((availableHeight - totalRowHeight) / 2, 0)
        tableView.contentInset = UIEdgeInsets(top: insetTop, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return quizTopics.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomTableViewCell", for: indexPath) as! CustomTableViewCell
        let topic = quizTopics[indexPath.row]
        cell.configure(with: topic)
        cell.selectionStyle = .blue
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        resetQuiz()
        print("Row \(indexPath.row) selected, starting quiz for topic: \(quizTopics[indexPath.row].title)")
        startQuiz(at: indexPath.row)
    }

    func setupQuestionUI() {
        questionLabel.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 100)
        questionLabel.numberOfLines = 0
        questionLabel.textAlignment = .center
        view.addSubview(questionLabel)

        buttonsStackView.frame = CGRect(x: 20, y: 200, width: view.bounds.width - 40, height: 300)
        buttonsStackView.axis = .vertical
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 10
        view.addSubview(buttonsStackView)

        submitButton.setTitle("Submit", for: .normal)
        submitButton.backgroundColor = .blue
        submitButton.layer.cornerRadius = 5
        submitButton.addTarget(self, action: #selector(submitAnswer), for: .touchUpInside)
        submitButton.frame = CGRect(x: 20, y: 520, width: view.bounds.width - 40, height: 50)
        submitButton.isHidden = true
        view.addSubview(submitButton)

        nextButton.setTitle("Next", for: .normal)
        nextButton.backgroundColor = .green
        nextButton.layer.cornerRadius = 5
        nextButton.addTarget(self, action: #selector(handleNext), for: .touchUpInside)
        nextButton.frame = CGRect(x: 20, y: 580, width: view.bounds.width - 40, height: 50)
        nextButton.isHidden = true
        view.addSubview(nextButton)

        resultLabel.frame = CGRect(x: 20, y: 500, width: view.bounds.width - 40, height: 50)
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.isHidden = true
        view.addSubview(resultLabel)
        
        backButton.setTitle("Back", for: .normal)
        backButton.backgroundColor = .systemBlue
        backButton.setTitleColor(.white, for: .normal)
        backButton.layer.cornerRadius = 5
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(backToTopicsButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 20),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 200),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc func backToTopicsButtonTapped() {
        resetQuiz()
        if let navController = navigationController {
            navController.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    func startQuiz(at index: Int) {
        currentQuizIndex = index
        currentQuestionIndex = 0
        correctAnswersCount = 0
        selectedAnswerIndex = nil
        tableView.isHidden = true
        resultLabel.isHidden = true
        showQuestion()
        nextButton.setTitle("Next", for: .normal)
        nextButton.addTarget(self, action: #selector(handleNext), for: .touchUpInside)
        nextButton.isHidden = true
        self.title = quizTopics[index].title
    }

    func showQuestion() {
        guard currentQuizIndex < quizTopics.count,
              currentQuestionIndex < quizTopics[currentQuizIndex].questions.count else {
            print("Index out of range")
            return
        }

        let question = quizTopics[currentQuizIndex].questions[currentQuestionIndex]
        questionLabel.text = question.text
        questionLabel.isHidden = false
        buttonsStackView.isUserInteractionEnabled = true
        setupAnswerButtons(for: question)
        
        buttonsStackView.isHidden = false
        resultLabel.isHidden = false
        submitButton.isHidden = true
        backButton.isHidden = false
    }
    
    func setupAnswerButtons(for question: Question) {
        buttonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, answer) in question.answers.enumerated() {
            let button = UIButton()
            button.setTitle(answer, for: .normal)
            button.tag = index
            button.backgroundColor = .lightGray
            button.addTarget(self, action: #selector(optionSelected(_:)), for: .touchUpInside)
            button.layer.cornerRadius = 5
            button.clipsToBounds = true
            button.isEnabled = true
            buttonsStackView.addArrangedSubview(button)
        }
    }


    @objc func optionSelected(_ sender: UIButton) {
        for button in buttonsStackView.arrangedSubviews as! [UIButton] {
            button.backgroundColor = .lightGray
        }
        sender.backgroundColor = .darkGray
        selectedAnswerIndex = sender.tag
        submitButton.isHidden = false
        submitButton.isEnabled = true
    }


    @objc func submitAnswer() {
        guard let selectedIndex = selectedAnswerIndex,
              let correctAnswerIndex = Int(quizTopics[currentQuizIndex].questions[currentQuestionIndex].correctAnswer) else {
            print("Error: There was a problem submitting the answer.")
            return
        }

        let adjustedIndex = correctAnswerIndex - 1
        if selectedIndex == adjustedIndex {
            resultLabel.text = "Correct!"
            correctAnswersCount += 1
        } else {
            let correctAnswer = quizTopics[currentQuizIndex].questions[currentQuestionIndex].answers[adjustedIndex]
            resultLabel.text = "Wrong! The correct answer was: \(correctAnswer)"
        }

        submitButton.isHidden = true
        nextButton.isHidden = false
        buttonsStackView.isUserInteractionEnabled = false
    }

    func resetQuiz() {
        resultLabel.text = ""
        questionLabel.isHidden = true
        buttonsStackView.isHidden = true
        submitButton.isHidden = true
        submitButton.isEnabled = true
        nextButton.isHidden = true
        tableView.isHidden = false
        backButton.isHidden = true
        resultLabel.isHidden = true
        tableView.reloadData()
    }

    @objc func handleNext() {
        selectedAnswerIndex = nil
        if currentQuestionIndex < quizTopics[currentQuizIndex].questions.count - 1 {
            currentQuestionIndex += 1
            resultLabel.isHidden = true
            tableView.isHidden = true
            resultLabel.text = ""
            showQuestion()
        } else {
            finishQuiz()
        }
    }

    func finishQuiz() {
        let totalQuestions = quizTopics[currentQuizIndex].questions.count
        let scoreText = "Quiz Finished! You got \(correctAnswersCount) out of \(totalQuestions) correct."
        
        questionLabel.isHidden = true
        tableView.isHidden = true
        buttonsStackView.isHidden = true
        submitButton.isHidden = true
        nextButton.isHidden = true
        
        resultLabel.isHidden = false
        let performanceRatio = Double(correctAnswersCount) / Double(totalQuestions)
        var performanceFeedback = ""
        if performanceRatio == 1.0 {
            performanceFeedback = "Perfect!"
        } else if performanceRatio >= 0.75 {
            performanceFeedback = "Almost there!"
        } else if performanceRatio >= 0.5 {
            performanceFeedback = "Good effort, but can improve."
        } else {
            performanceFeedback = "Try harder next time!"
        }
        resultLabel.text = "\(scoreText)\n\(performanceFeedback)"

        nextButton.setTitle("Back to Topics", for: .normal)
        nextButton.removeTarget(self, action: nil, for: .allEvents)
        nextButton.addTarget(self, action: #selector(backToTopics), for: .touchUpInside)
        backButton.isHidden = true
        nextButton.isHidden = false
    }

    @objc func backToTopics() {
        tableView.isHidden = false
        questionLabel.isHidden = true
        resultLabel.isHidden = true
        buttonsStackView.isHidden = true
        resetQuiz()
        navigationController?.popToRootViewController(animated: true)
    }

    func fetchQuizData() {
        NetworkManager.shared.fetchQuizzes { [weak self] result in
            switch result {
            case .success(let quizzes):
                DispatchQueue.main.async {
                    self?.quizTopics = quizzes
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showError(message: "Failed to fetch quizzes: \(error.localizedDescription)")
                }
            }
        }
    }

    func setupToolbar() {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])

        let settingsButton = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(showSettings))
        toolbar.setItems([settingsButton], animated: true)
    }

    @objc func showSettings() {
        let alertController = UIAlertController(title: "Settings", message: "Configure your settings", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "Enter data source URL"
            textField.text = UserDefaults.standard.string(forKey: "DataSourceURL") ?? "https://tednewardsandbox.site44.com/questions.json"
        }

        let saveAction = UIAlertAction(title: "Check Now", style: .default) { [weak self] _ in
            guard let textField = alertController.textFields?.first, let urlString = textField.text else {
                self?.showError(message: "Please enter a valid URL.")
                return
            }

            UserDefaults.standard.set(urlString, forKey: "DataSourceURL")
            NetworkManager.shared.updateQuizzesURL(with: urlString)
            self?.fetchQuizData()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    
    func showError(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}
