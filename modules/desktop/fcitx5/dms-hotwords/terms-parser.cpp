#include <iostream>
#include <nlohmann/json.hpp>
#include "vocotype/common/terms_yaml.hpp"

// Use exactly the parser shipped with our pinned VoCoType version.
int main() {
    try {
        auto document = vocotype::common::parse_terms_yaml(std::cin);
        nlohmann::json terms = nlohmann::json::array();
        for (const auto &term : document.terms)
            terms.push_back({{"canonical", term.canonical}, {"aliases", term.aliases},
                             {"hotwords", term.hotwords}, {"protect", term.protect}});
        std::cout << nlohmann::json{{"terms", terms}, {"protect", document.protected_phrases}} << '\n';
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
