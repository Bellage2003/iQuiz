//
//  ViewController.swift
//  iQuiz
//
//  Created by 小戈 on 2024/5/3.
//

import UIKit

struct QuizTopic {
    var icon: String
    var title: String
    var description: String
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
        iconImageView.image = UIImage(named: topic.icon) ?? UIImage(systemName: "photo")
        titleLabel.text = topic.title
        descriptionLabel.text = topic.description

        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
    }
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var tableView: UITableView!
    var quizTopics = [
        QuizTopic(icon: "math_icon", title: "Mathematics", description: "Challenges for the number enthusiast."),
        QuizTopic(icon: "heroes_icon", title: "Marvel Super Heroes", description: "Test your knowledge of Marvel Universe."),
        QuizTopic(icon: "science_icon", title: "Science", description: "Explore the world of Science.")
    ]
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let totalRowHeight = tableView.contentSize.height
        let additionalSpace = tableView.bounds.height - totalRowHeight
        
        if additionalSpace > 0 {
            tableView.contentInset.top = additionalSpace / 2
            tableView.contentInset.bottom = additionalSpace / 2
        } else {
            tableView.contentInset.top = 0
            tableView.contentInset.bottom = 0
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "iQuiz"
        setupTableView()
        setupToolbar()
    }

    func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.register(CustomTableViewCell.self, forCellReuseIdentifier: "CustomTableViewCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return quizTopics.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomTableViewCell", for: indexPath) as! CustomTableViewCell
        let topic = quizTopics[indexPath.row]
        cell.configure(with: topic)
        return cell
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
        let alertController = UIAlertController(title: "Settings go here", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}
