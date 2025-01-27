##' Server of the Radish application
##'
##' @title Radish server
##' @param input ui input
##' @param output ui output
##' @param session shiny session
##' @export
radish_server <- function(input, output, session) {
  my_values <- reactiveValues(
    given_genes_rows = NULL
  )
  observeEvent(list_loaded$all_results_choice(), {
    updateSelectInput(
      inputId = "contrast_act",
      choices = list_loaded$all_results_choice()
    )
  })


  list_loaded <- InputServer("inp", reactive(input$contrast_act))

  PcaServer(
    id = "pca",
    config = list_loaded$config,
    txi.rsem = list_loaded$txi.rsem,
    rld = list_loaded$rld
  )
  sel_table <- GeneTableServer(
    id = "gntab",
    res = list_loaded$res
  )
  CountsServer(
    id = "cnts",
    counts = list_loaded$counts,
    config = list_loaded$config,
    sel_genes_table = sel_table
  )
  MAplotServer(
    id = "ma",
    res = list_loaded$res,
    contrast_act = reactive(input$contrast_act),
    contrastes = list_loaded$contrastes,
    sel_genes_table = sel_table
  )
  VolcanoServer(
    id = "vp",
    res = list_loaded$res,
    contrast_act = reactive(input$contrast_act),
    contrastes = list_loaded$contrastes,
    sel_genes_table = sel_table
  )
  HeatmapServer(
    id = "hm",
    counts = list_loaded$counts,
    res = list_loaded$res,
    config = list_loaded$config,
    contrast_act = reactive(input$contrast_act),
    contrastes = list_loaded$contrastes,
    sel_genes_table = sel_table
  )
  UpsetServer(
    id = "up",
    all_results = list_loaded$all_results,
    all_results_choice = list_loaded$all_results_choice,
    res = list_loaded$res
  )
}
