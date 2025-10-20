return {
    {
        "lihaoze123/competitest.nvim",
        dependencies = {
            "MunifTanjim/nui.nvim"
        },
        opts = {
            template_file = ".template.cpp",
            testcases_directory = "./.testcases",
            compile_command = {
                cpp = { exec = 'g++', args = { '$(FNAME)', '-o', '$(FNOEXT)', '-std=c++23', '-fsanitize=undefined', '-g' } },
            },
            run_command = {
                go = { exec = 'go', args = { "run", "$(FNAME)" } }
            },
            received_contests_directory = "./.contest/$(CONTEST)",
        },
        keys = {
            {"<leader>Cr", "<cmd>CompetiTest run<cr>", desc = "CompetiTest run"},
            {"<leader>CRp", "<cmd>CompetiTest receive problem<cr>", desc = "CompetiTest receive problem"},
            {"<leader>CRt", "<cmd>CompetiTest receive testcases<cr>", desc = "CompetiTest receive testcases"},
            {"<leader>CRc", "<cmd>CompetiTest receive contest<cr>", desc = "CompetiTest receive contest"},
            {"<leader>Ca", "<cmd>CompetiTest add_testcase<cr>", desc = "CompetiTest add_testcase"},
            {"<leader>Ce", "<cmd>CompetiTest edit_testcase<cr>", desc = "CompetiTest edit_testcase"},
        }
    }
}
