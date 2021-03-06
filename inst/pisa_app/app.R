library(shiny)
library(shinyWidgets)
library(dplyr)
library(htmlwidgets)
library(pisaR)

## load data into the app
source("./data_scripts/load_data.R")

# Define UI for application
ui <- navbarPage(
  windowTitle = "WHO | PISA",
  # Application title with links to WHO and PISA
  title = HTML('<span class="navtitle"><a rel="home" href="http://who.int" title="World Health Organization"><img class = "whoimg" src="who_logo_white40px.png"></a><a rel="home" href="http://www.who.int/influenza/surveillance_monitoring/pisa/en/" title="PISA Home Page"><span class="navtext">Pandemic and Epidemic Influenza Severity Assessment</a></span></span>'),
  tabPanel(title = "Home",
           #load static HTML content for Home and About
           HTML(readLines("./www/home_page.html"))),
  tabPanel(title = "About",
           HTML(readLines("./www/about_page.html"))),
  tabPanel(title = "Explore Data",
  fluidRow(
    ###FILTERS UI
    column(3,
           sidebarPanel(width = 12,
                        h3("Data Filters"),
                        uiOutput(outputId = "level_filter"),
                        uiOutput(outputId = "confidence_level_filter"),
                        fluidRow(column(6,uiOutput(outputId = "season_start")),
                        column(6,uiOutput(outputId = "season_end"))),
                        h3("Map Only"),
                        uiOutput(outputId = "week_filter"),
                        h3("Heat map Only"),
                        uiOutput(outputId = "region_filter")
                        )
                        ),
    # add style sheet
    includeCSS("./www/style.css"),
    ### PLOT TABS
    column(9, tabsetPanel(
      id = "explore",
      # Transmissibility Tab
      tabPanel(title = "Transmissibility",
               h4("Click Country to Zoom In/Out"),
               fluidRow(pisaROutput("map_transmission", width = "100%", height = "450px")),
               fluidRow(pisaROutput("heatmap_transmission",
                                    width = "100%",
                                    height = paste0(length(unique(df$COUNTRY_TITLE))*40, "px")))
        ),
      # Seriousness Tab
      tabPanel(title = "Seriousness",
               h4("Click Country to Zoom In/Out"),
               fluidRow(pisaROutput("map_seriousness", width = "100%", height = "450px")),
               fluidRow(pisaROutput("heatmap_seriousness",
                                    width = "100%",
                                    height = paste0(length(unique(df$COUNTRY_TITLE))*40, "px")))
               ),
      # Impact Tab
      tabPanel(title = "Impact",
               h4("Click Country to Zoom In/Out"),
               fluidRow(pisaROutput("map_impact", width = "100%", height = "450px")),
               fluidRow(pisaROutput("heatmap_impact",
                                    width = "100%",
                                    height = paste0(length(unique(df$COUNTRY_TITLE))*40, "px")))
               )
      )
    )
  )
  ),
  id = "title_bar"
)

# Define server logic
server <- function(input, output,session) {

  ## render UI elements using data available
  output$year <- renderUI({
    selectInput("year_filter", "Select A Year", choices = year_ui, selected = max(year_ui))
  })

  output$level_filter <- renderUI({
    checkboxGroupInput("level_filter",
                "Select Level of Activity",
                choices = levels_ui,
                selected = levels_ui,
                inline = FALSE)
  })

  output$confidence_level_filter <- renderUI({
    checkboxGroupInput("cl_filter",
                "Select Confidence Level",
                choices = confidence_ui,
                selected = confidence_ui)
  })

  output$region_filter <- renderUI({
    checkboxGroupInput("region_filter",
                "Select a Region",
                choices = who_region_ui,
                selected = who_region_ui,
                inline = FALSE)
  })

  output$season_start <- renderUI({
    textInput("season_start", "Start (YEAR-WEEK)", value = paste0(max(year_ui), "-01"))
  })

  output$season_end <- renderUI({
    textInput("season_end", "End (YEAR-WEEK)", value = paste0(max(year_ui), "-52"))
  })

  output$week_filter <- renderUI({
    req(filter_data())
    df <- filter_data()
    weeks <- unique(df$ISO_YW)
    weeks <- sort(weeks)
    sliderTextInput(inputId =  "week_filter",
                 label = "Select a Year and Week",
                 choices = weeks,
                 selected = weeks[1],
                 #to = weeks[length(weeks)],
                 grid = FALSE)
  })

  ##### FILTER SERVER SIDE OPERATIONS#####
  filter_data <- reactive({
    req(input$season_start)
    ##season filter breakdown
    start <- gsub("-", "",input$season_start)
    end <- gsub("-", "",input$season_end)

    # season and region filtered table
    # level and confidence level depends on which tab (id = explore) is active
    if(input$explore == "Transmissibility"){
      df_this <- df %>%
        filter(ISOYW >= start) %>%
        filter(ISOYW <= end) %>%
        filter(WHOREGION %in% input$region_filter) %>%
        filter(TRANSMISSION %in% input$level_filter) %>%
        filter(TRANSMISSION_CL %in% input$cl_filter) %>%
        filter(!is.null(ISOYW))
    } else if(input$explore == "Seriousness"){
      df_this <- df %>%
        filter(ISOYW >= start) %>%
        filter(ISOYW <= end) %>%
        filter(WHOREGION %in% input$region_filter) %>%
        filter(SERIOUSNESS %in% input$level_filter) %>%
        filter(SERIOUSNESS_CL %in% input$cl_filter)%>%
        filter(!is.null(ISOYW))
    } else if(input$explore == "Impact") {
      df_this <- df %>%
        filter(ISOYW >= start) %>%
        filter(ISOYW <= end) %>%
        filter(WHOREGION %in% input$region_filter) %>%
        filter(IMPACT %in% input$level_filter) %>%
        filter(IMPACT_CL %in% input$cl_filter)%>%
        filter(!is.null(ISOYW))
    }

  })

  ############# transmission ###################
  ### MAP ###
  output$map_transmission <- renderPisaR({
    req(input$week_filter)
      pisaR()%>%
      createLayer(layerType = "globalMap",
                  layerColor = list("green","yellow", "orange", "red", "darkred"),
                  layerLabel = "map",
                  layerData = filter_data() %>%
                    filter(ISO_YW == input$week_filter) %>%
                    select(TRANSMISSION, TRANSMISSION_CL, TRANSMISSION_COM,ISO2, ISO_YW),
                  layerMapping = list(color_var = "TRANSMISSION",
                                      time_var = "ISO_YW",
                                      key_data = "ISO2",
                                      key_map = "ISO_2_CODE",
                                      cl_var = "TRANSMISSION_CL",
                                      com_var = "TRANSMISSION_COM")) %>%
      defineColorScale(color_palette = list("green","yellow", "orange", "red", "purple", "lightgray", "gray"),
                       color_key = list("Below seasonal threshold", "Low", "Moderate", "High", "Extra-ordinary", "Not Available", "Not Applicable")) %>%
      definePlotMargin(top = 0, left = 10, bottom = 100, right = 150) %>%
      assignMapColor(country = list("GL", "EH"), color = "darkgrey")

  })
  ### HEATMAP ###
  output$heatmap_transmission <- renderPisaR({
    ##country filter from the map click event
    if(!is.null(input$country_input)){
      if(input$country_input %in% filter_data()[["ISO2"]]){
        df_that <- filter_data() %>%
          filter(ISO2 == input$country_input)
      } else {
        df_that <- filter_data()
      }

    } else {
      df_that <- filter_data()
    }
    #define week interval
    df <- df_that
    weeks <- unique(df$ISO_YW)
    weeks <- sort(weeks)
    #draw chart
    pisaR() %>%
      createLayer(layerType = "heatmap",
                  layerColor = list("green","yellow", "orange", "red", "darkred"),
                  layerLabel = "heat",
                  layerData = df_that %>%
                    select(TRANSMISSION, TRANSMISSION_CL, TRANSMISSION_COM,COUNTRY_TITLE, ISO_YW, ISOYW) %>%
                    arrange(desc(COUNTRY_TITLE), ISOYW),
                  layerMapping = list(x_var = 'ISO_YW',
                                      y_var = 'COUNTRY_TITLE',
                                      z_var = "TRANSMISSION",
                                      cl_var = "TRANSMISSION_CL",
                                      com_var = "TRANSMISSION_COM")) %>%
      defineColorScale(color_palette = list("green","yellow", "orange", "red", "purple", "lightgray", "gray"),
                       color_key = list("Below", "Low", "Moderate", "High", "Extra-ordinary", "Not Available", "Not Applicable")) %>%
      definePlotMargin(left = 110) %>%
      defineTimeInterval(interval = weeks)

  })
  ############# seriousness ###################
  ### MAP ###
  output$map_seriousness <- renderPisaR({
    req(input$week_filter)
    pisaR()%>%
      createLayer(layerType = "globalMap",
                  layerColor = list("green","yellow", "orange", "red", "darkred"),
                  layerLabel = "map",
                  layerData = filter_data() %>%
                    filter(ISO_YW == input$week_filter) %>%
                    select(SERIOUSNESS, SERIOUSNESS_CL, SERIOUSNESS_COM, COUNTRY_CODE, ISO_YW),
                  layerMapping = list(color_var = "SERIOUSNESS",
                                      time_var = "ISO_YW",
                                      key_data = "COUNTRY_CODE",
                                      key_map = "ISO_3_CODE",
                                      cl_var = "SERIOUSNESS_CL",
                                      com_var = "SERIOUSNESS_COM")) %>%
      defineColorScale(color_palette = list("green","yellow", "orange", "red", "purple", "lightgray", "gray"),
                       color_key = list("Below", "Low", "Moderate", "High", "Extra-ordinary", "Not Available", "Not Applicable")) %>%
      definePlotMargin(top = 0, left = 10, bottom = 100, right = 150)%>%
      assignMapColor(country = list("GL", "EH"), color = "darkgrey")

  })

  ### HEATMAP ###
  output$heatmap_seriousness <- renderPisaR({
    ##country filter from the map click event
    if(!is.null(input$country_input)){
      if(input$country_input %in% filter_data()[["ISO2"]]){
        df_that <- filter_data() %>%
          filter(ISO2 == input$country_input)
      } else {
        df_that <- filter_data()
      }

    } else {
      df_that <- filter_data()
    }
    #define week interval
    df <- df_that
    weeks <- unique(df$ISO_YW)
    weeks <- sort(weeks)

    pisaR() %>%
      createLayer(layerType = "heatmap",
                  layerColor = list("green","yellow", "orange", "red", "darkred"),
                  layerLabel = "heat",
                  layerData = df_that %>%
                    select(SERIOUSNESS, SERIOUSNESS_CL, SERIOUSNESS_COM,COUNTRY_TITLE, ISOYW, ISO_YW) %>%
                    arrange(desc(COUNTRY_TITLE),ISOYW),
                  layerMapping = list(x_var = 'ISO_YW',
                                      y_var = 'COUNTRY_TITLE',
                                      z_var = "SERIOUSNESS",
                                      cl_var = "SERIOUSNESS_CL",
                                      com_var = "SERIOUSNESS_COM")) %>%
      defineColorScale(color_palette = list("green","yellow", "orange", "red", "purple", "lightgray", "gray"),
                       color_key = list("Below", "Low", "Moderate", "High", "Extra-ordinary", "Not Available", "Not Applicable")) %>%
      definePlotMargin(left = 110) %>%
      defineTimeInterval(interval = weeks)

  })

  ############# impact ###################
  ### MAP ###
  output$map_impact <- renderPisaR({
    req(input$week_filter)
    pisaR()%>%
      createLayer(layerType = "globalMap",
                  layerColor = list("green","yellow", "orange", "red", "darkred"),
                  layerLabel = "map",
                  layerData = filter_data() %>%
                    filter(ISO_YW == input$week_filter) %>%
                    select(IMPACT, IMPACT_CL, IMPACT_COM,COUNTRY_CODE, ISO_YW),
                  layerMapping = list(color_var = "IMPACT",
                                      time_var = "ISO_YW",
                                      key_data = "COUNTRY_CODE",
                                      key_map = "ISO_3_CODE",
                                      cl_var = "IMPACT_CL",
                                      com_var = "IMPACT_COM")) %>%
      defineColorScale(color_palette = list("green","yellow", "orange", "red", "purple", "lightgray", "gray"),
                       color_key = list("No Impact", "Low", "Moderate", "High", "Extra-ordinary", "Not Available", "Not Applicable")) %>%
      definePlotMargin(top = 0, left = 10, bottom = 100, right = 150)%>%
      assignMapColor(country = list("GL", "EH"), color = "darkgrey")

  })

  ### HEATMAP ###
  output$heatmap_impact <- renderPisaR({
    ##country filter from the map click event
    if(!is.null(input$country_input)){
      if(input$country_input %in% filter_data()[["ISO2"]]){
        df_that <- filter_data() %>%
          filter(ISO2 == input$country_input)
      } else {
        df_that <- filter_data()
      }

    } else {
      df_that <- filter_data()
    }
    #define week interval
    df <- df_that
    weeks <- unique(df$ISO_YW)
    weeks <- sort(weeks)

    pisaR() %>%
      createLayer(layerType = "heatmap",
                  layerColor = list("green","yellow", "orange", "red", "darkred"),
                  layerLabel = "heat",
                  layerData = df_that %>%
                    select(IMPACT, IMPACT_CL, IMPACT_COM,COUNTRY_TITLE, ISOYW, ISO_YW) %>%
                    arrange(desc(COUNTRY_TITLE),ISOYW),
                  layerMapping = list(x_var = 'ISO_YW',
                                      y_var = 'COUNTRY_TITLE',
                                      z_var = "IMPACT",
                                      cl_var = "IMPACT_CL",
                                      com_var = "IMPACT_COM")) %>%
      defineColorScale(color_palette = list("green","yellow", "orange", "red", "purple", "lightgray", "gray"),
                       color_key = list("below", "Low", "Moderate", "High", "Extra-ordinary", "Not Available", "Not Applicable")) %>%
      definePlotMargin(left = 110) %>%
      defineTimeInterval(interval = weeks)

  })
}

# Run the application
shinyApp(ui = ui, server = server)

