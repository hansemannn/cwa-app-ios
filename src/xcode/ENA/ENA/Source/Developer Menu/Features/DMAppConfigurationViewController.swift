//
// Corona-Warn-App
//
// SAP SE and all other contributors
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

#if !RELEASE

import UIKit

class DMAppConfigurationViewController: UIViewController {

	// MARK: - Init

	init(appConfiguration: AppConfigurationProviding) {
		self.appConfiguration = appConfiguration

		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Overrides

	override func viewDidLoad() {
		super.viewDidLoad()

		setUp()
	}

	// MARK: - Private

	private let appConfiguration: AppConfigurationProviding

	private let textView = UITextView()

	private func setUp() {
		title = "🔬 App Configuration"

		textView.isEditable = false

		view.addSubview(textView)
		textView.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			view.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
			view.topAnchor.constraint(equalTo: textView.topAnchor),
			view.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
			view.bottomAnchor.constraint(equalTo: textView.bottomAnchor)
		])

		appConfiguration.appConfiguration { [weak self] result in
			switch result {
			case .success(let appConfig):
				self?.textView.text = appConfig.textFormatString()
			case .failure(let error):
				self?.textView.text = error.localizedDescription
			}
		}
	}

}

#endif
