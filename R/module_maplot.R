# Maplot module

# UI ---------------------------------------------------------------------------
MAplotUI <- function(id) {
  ns <- NS(id)
  tagList(fluidRow(
    bs4Dash::tabBox(
               width = 12,
               tabPanel(title = "Static",
                        status = "primary",
                        width = 12,
                        plotOutput(outputId = ns("plot")),
                        bs4Dash::actionButton(ns("draw"), "Draw MA-Plot",
                                              status = "secondary"),
                        bs4Dash::actionButton(ns("reset"), "Reset defaults",
                                              status = "secondary")
                        ),
               tabPanel(title = "Interactive",
                        width = 12,
                        plotly::plotlyOutput(ns("plotly"),
                                             height = "600px")
                        )
               )
             ),
        fluidRow(
          bs4Dash::box(title = "Appearance",
              status = "info",
              width = 4,
              colourpicker::colourInput(
                inputId = ns("up_col"),
                label = "Choose the color of the upregulated genes",
                value = "#fe7f00"
              ),
              colourpicker::colourInput(
                inputId = ns("down_col"),
                label = "Choose the color of the downregulated genes",
                value = "#007ffe"
              ),
              selectInput(
                inputId = ns("theme"),
                label = "Choose the theme for the plot",
                choices = themes_gg,
                selected = "Classic"
              ),
              sliderInput(
                inputId = ns("ratio"),
                label = "Choose the plot aspect ratio",
                value = 1,
                min = 0.5,
                max = 2
              ),
              sliderInput(
                     inputId = ns("y_max"),
                     label = "Maximum value of the y axis",
                     min = 0,
                     max = 100,
                     value = 10
                   )
          ),
          bs4Dash::box(title = "Text",
              status = "info",
              width = 4,
              textInput(
                inputId = ns("plot_title"),
                label = "Title of the plot",
                value = "Gene expression change"
              ),
              textInput(
                inputId = ns("up_leg"),
                label = "Choose the upregulated legend name",
                value = "up"
              ),
              textInput(
                inputId = ns("down_leg"),
                label = "Choose the downregulated legend name",
                value = "down"
              ),
              textInput(
                inputId = ns("ns_leg"),
                label = "Choose the nonsignificant legend name",
                value = "ns"
              ),
              GeneSelectUI(ns("gnsel")),
              sliderInput(
                inputId = ns("lab_size"),
                label = "Choose the size of the labels",
                value = 3,
                min = 1,
                max = 4,
                step = .25
              )
          ),
          bs4Dash::box(title = "Download",
              status = "info",
              width = 4,
              DownloadUI(ns("dw")) 
          )
        )
      )
}


# Server -----------------------------------------------------------------------
MAplotServer <- function(id,
                         res,
                         contrast_act,
                         contrastes,
                         sel_genes_table) {
  stopifnot(is.reactive(res))
  stopifnot(is.reactive(contrast_act))
  stopifnot(is.reactive(contrastes))
  stopifnot(is.reactive(sel_genes_table))
  moduleServer(id, function(input, output, session){
    
    genes_selected <- GeneSelectServer(
      id = "gnsel",
      src_table = res,
      sel_genes_table = sel_genes_table
    )
    
    observeEvent({
      contrast_act()
      contrastes()
    }, {
      updateTextInput(
        inputId = "plot_title",
        value = paste(" Gene expression change in",
                      contr_str(contrastes(), contrast_act(), sep = " vs "))
      )
    })
    
    observeEvent(res(), {
      updateSliderInput(
        inputId = "y_max",
        max = lfc_max_abs(donnees = res()),
        value = lfc_max_abs(donnees = res())
      )
    })

    observeEvent(input$reset, {
      colourpicker::updateColourInput(session = session, "up_col", value = "#fe7f00")
      colourpicker::updateColourInput(session = session, "down_col", value = "#007ffe")
      updateSelectInput(inputId = "theme", selected = "Classic")
      updateSliderInput(inputId = "ratio", value = 1)
      updateTextInput(inputId = "up_leg", value = "up")
      updateSliderInput(inputId = "y_max", value = lfc_max_abs(donnees = res()))
      updateTextInput(inputId = "down_leg", value = "down")
      updateTextInput(inputId = "ns_leg", value = "ns")
      updateSliderInput(inputId = "lab_size", value = 3)
      req(contrast_act())
      updateTextInput(
        inputId = "plot_title",
        value = paste(" Gene expression change in",
                      contr_str(contrastes(), contrast_act(), sep = " vs "))
      )
    })
    


    plot_data <- eventReactive({
      res()
      input$y_max
    }, {
      res() %>%
        mutate(outside = case_when(
          abs(log2FoldChange) > input$y_max ~ "out",
          TRUE ~ "in"
        ))
    })


    cur_plot <- eventReactive(input$draw, {
      req(res())
      my_maplot(
        plot_data = plot_data(),
        title = input$plot_title,
        colors = c("up" = input$up_col, "down" = input$down_col),
        legends = c("up" = input$up_leg, "down" = input$down_leg, "ns" = input$ns_leg),
        ratio = input$ratio,
        selected_genes = c(genes_selected$sel_genes_names(),
                           genes_selected$sel_genes_ids()),
        y_axis_max = input$y_max,
        theme = input$theme,
        label_size = input$lab_size
      )
    })
    
    output$plot <- renderPlot({
      req(cur_plot())
      cur_plot()
    })

    output$plotly <- plotly::renderPlotly({
      req(res())
      ggpl <- my_maplot(
        plot_data = plot_data(),
        colors = c("up" = input$up_col, "down" = input$down_col),
        legends = c("up" = input$up_leg, "down" = input$down_leg, "ns" = input$ns_leg),
        y_axis_max = input$y_max,
        ratio = input$ratio,
        theme = input$theme
      )

      ggply <- plotly::ggplotly(p = ggpl,
                                tooltip = c("text"),
                                dynamicTicks = TRUE,
                                height = 600,
                                width = 600
                                )
      plotly::toWebGL(ggply)
    })
    
    DownloadServer(
      id = "dw",
      cur_plot = cur_plot,
      plotname = reactive("MA_plot"),
      ratio = reactive(input$ratio)
    )
  })
}
    


# Test App ---------------------------------------------------------------------
MAplotApp <- function() {
  ui <- fluidPage(
    bs4Dash::tabsetPanel(type = "tabs",
    tabPanel("input", InputUI("inp")),
    tabPanel("Maplot", MAplotUI("maplot1"))
    )
  )
  server <- function(input, output, session) {
    list_loaded <- InputServer("inp", reactive("1"))
    MAplotServer(id = "maplot1",
                  res = list_loaded$res,
                  contrast_act = reactive("1"),
                 contrastes = list_loaded$contrastes,
                  sel_genes_table = reactive(data.frame(head(list_loaded$res()))))
    
  }
  shinyApp(ui, server)
}
