# Module for input

# All the objects expected in the input
expected_data <- c(
  "dataMerged",
  "all_results",
  "configuration",
  "contrasteList",
  "rld",
  "txi.rsem"
)

# UI ---------------------------------------------------------------------------
InputUI <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      bs4Dash::box(
        title = "Input",
        status = "info",
        width = 3,
        fileInput(ns("res_data"),
                  "Results"
        ),
        bs4Dash::actionButton(ns("demo"), "Load demo data")
      ),
      bs4Dash::box(
        title = "Contents",
        width = 9,
        status = "info",
        fluidRow(
          bs4Dash::valueBoxOutput(ns("samples"),
                         width = 4),
          bs4Dash::valueBoxOutput(ns("contrastes"),
                         width = 4),
          bs4Dash::valueBoxOutput(ns("conditions"),
                         width = 4)
        )
      )
    ),
    fluidRow(
      bs4Dash::box(
        title = "Configuration Table",
        status = "info",
        width = 12,
        collapsed = TRUE,
        tableOutput(ns("config_table"))
      )
    )
  )
}


# Server -----------------------------------------------------------------------
InputServer <- function(id, contrast_act) {
  stopifnot(is.reactive(contrast_act))
  moduleServer(id, function(input, output, session) {
    # rds-sourced list, inpendent of demo or user-loaded data
    data <- reactiveVal()
    
    
    demo_data <- eventReactive(input$demo, {
      tmp <- readRDS("../exdata/demo_data.rds")
      validate(need(all(expected_data == names(tmp)), "Missing objects in loaded file"))
      tmp
    })
    
    
    data_loaded <- eventReactive({
      input$res_data
    }, {
      req(input$res_data)
      extension <- tools::file_ext(input$res_data$name)
      tmp <- switch(extension,
                    rds = readRDS(input$res_data$datapath),
                    RDS = readRDS(input$res_data$datapath),
                    validate("Invalid file : Need a .rds file")
      )
      validate(need(all(expected_data == names(tmp)), "Missing objects in loaded file"))
      tmp
    })
    
    #switch data to the correct (last modified) data source
    observeEvent(demo_data(), data(demo_data()))
    observeEvent(data_loaded(), data(data_loaded()))
    
    
    counts <- eventReactive(data(),{
      req(data())
      # Permet de remplacer un nom variable (hgcn_symbol, mgi_symbol) par un nom fixe
      tmp <- data()[["dataMerged"]] %>%
        dplyr::rename("symbol" = dplyr::contains("symbol"))
      # Avoids duplicated symbol names
      tmp$symbol %<>% tidy_symbols()
      tmp
    })
    
    all_results <- eventReactive(data(),{
      req(data())
      tmp <- vector(mode = "list", length = length(data()[["all_results"]]))
      for (contraste in seq_along(data()[["all_results"]])) {
        tmp[[contraste]] <- data()[["all_results"]][[contraste]] %>% 
          dplyr::rename("symbol" = dplyr::contains("symbol"))
        tmp[[contraste]]$symbol %<>%
          tidy_symbols()
        tmp[[contraste]] <- add_bonferroni(tmp[[contraste]])
        tmp[[contraste]] <- add_sig_expr(
          tmp[[contraste]],
          lfc_filter = 0,
          pval_filter = 0.05,
          pval_column = "padj"
        )
      }
      tmp
    })
    
    rld <- eventReactive(data(),{
      req(data())
      data()[["rld"]]
    })
    
    config <- eventReactive(data(), {
      req(data())
      data()[["configuration"]]
    })
    
    contrastes_df <- eventReactive(data(), {
      req(data())
      data()[["contrasteList"]]
    })
    
    txi.rsem <- eventReactive(data(), {
      req(data())
      data()[["txi.rsem"]]
    })
    
    
    res <- eventReactive({
      contrast_act()
      all_results()
    }, {
      all_results()[[strtoi(contrast_act())]]
    })
    
    output$contrastes <- bs4Dash::renderValueBox({
      req(all_results())
      bs4Dash::valueBox(
        subtitle = "Contrastes",
        value = all_results() %>% length(),
        icon = icon("list"),
        color = "info"
      )
    })
    
    output$samples <- bs4Dash::renderValueBox({
      req(config())
      bs4Dash::valueBox(
        subtitle = "Samples",
        value = config() %>% nrow(),
        icon = icon("list"),
        color = "info"
      )
    })
    
    output$conditions <- bs4Dash::renderValueBox({
      req(config())
      bs4Dash::valueBox(
        subtitle = "Conditions",
        value = config() %>%
          pull(Condition) %>%
          n_distinct(),
        icon = icon("list"),
        color = "info"
      )
    })
    
    
    output$config_table <- renderTable(
      config() %>% select(-File),
      striped = TRUE,
      bordered = TRUE,
      spacing = "m",
    )
    

    observeEvent(counts(), {
      if(length(which(counts()$symbol == "")) != 0) {
        showModal(modalDialog(
          title = "The version of the .rds file does not match the version of Radish",
          "Please contact our team to recreate the .rds file with the up-to-date pipeline",
          easyClose = FALSE
        ))
      }
    })


    all_results_choice <- reactive({
      names_ch <- purrr::map2_chr(
        contrastes_df()[, 2],
        contrastes_df()[, 3],
        ~ paste(.x, .y, sep = " vs "))
      magrittr::set_names(seq_len(nrow(contrastes_df())), names_ch)
    })
    
    list(
      all_results = all_results,
      res = res,
      contrastes = contrastes_df,
      counts = counts,
      rld = rld,
      config = config,
      txi.rsem = txi.rsem,
      all_results_choice = all_results_choice
    )
  })
}


# Test App ---------------------------------------------------------------------
InputApp <- function() {
  ui <- fluidPage(InputUI("test"))
  
  server <- function(input, output, session) {
    InputServer("test", reactive("1"))
  }
  shinyApp(ui, server)
}
