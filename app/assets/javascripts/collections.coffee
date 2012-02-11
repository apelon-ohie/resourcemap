@initCollections = (initialCollections) ->
  SITES_PER_PAGE = 25

  window.markerImageInactive = new google.maps.MarkerImage(
    "/assets/marker_sprite_inactive.png",
    new google.maps.Size(20, 34),
    new google.maps.Point(0, 0),
    new google.maps.Point(10, 34),
  )
  window.markerImageInactiveShadow = new google.maps.MarkerImage(
    "/assets/marker_sprite_inactive.png",
    new google.maps.Size(37, 34),
    new google.maps.Point(20, 0),
    new google.maps.Point(10, 34),
  )
  window.markerImageTarget = new google.maps.MarkerImage(
    "/assets/marker_sprite_target.png",
    new google.maps.Size(20, 34),
    new google.maps.Point(0, 0),
    new google.maps.Point(10, 34),
  )
  window.markerImageTargetShadow = new google.maps.MarkerImage(
    "/assets/marker_sprite_target.png",
    new google.maps.Size(37, 34),
    new google.maps.Point(20, 0),
    new google.maps.Point(10, 34),
  )

  window.reloadMapSites = (callback) ->
    bounds = window.map.getBounds()

    # Wait until map is loaded
    unless bounds
      setTimeout(( -> window.reloadMapSites(callback)), 100)
      return

    ne = bounds.getNorthEast()
    sw = bounds.getSouthWest()
    collection_ids = if window.model.currentCollection()
                       [window.model.currentCollection().id()]
                     else
                        c.id for c in window.model.collections() when c.checked()
    currentSiteId = window.model.currentSite()?.id()
    query =
      n: ne.lat()
      s: sw.lat()
      e: ne.lng()
      w: sw.lng()
      z: window.map.getZoom()
      collection_ids: collection_ids
      exclude_id: currentSiteId

    window.requestNumber += 1
    currentRequestNumber = window.requestNumber

    getCallback = (data = {}) ->
      return unless currentRequestNumber == window.requestNumber

      currentSiteId = window.model.currentSite()?.id()
      selectedSiteId = window.model.selectedSite()?.id()

      sites = data.sites
      sites ||= []
      dataSiteIds = {}

      # Add markers if they are not already on the map
      for site in sites
        dataSiteIds[site.id] = site.id
        if !window.markers[site.id]
          markerOptions =
            map: window.map
            position: new google.maps.LatLng(site.lat, site.lng)
          # Show site in grey if editing a site (but not if it's the one being edited)
          if currentSiteId && currentSiteId != site.id
            markerOptions.icon = window.markerImageInactive
            markerOptions.shadow = window.markerImageInactiveShadow
          if selectedSiteId && selectedSiteId == site.id
            markerOptions.icon = window.markerImageTarget
            markerOptions.shadow = window.markerImageTargetShadow
          window.markers[site.id] = new google.maps.Marker markerOptions
          window.markers[site.id].siteId = site.id

      # Determine which markers need to be removed from the map
      # Don't remove the pin for the current site
      currentSiteId = (currentSiteId).toString() if currentSiteId
      toRemove = []
      for siteId, marker of window.markers
        if !dataSiteIds[siteId] && siteId != currentSiteId
          toRemove.push siteId

      # And remove them
      for siteId in toRemove
        window.deleteMarker siteId

      clusters = data.clusters
      clusters ||= []

      if window.reuseCurrentClusters
        dataClusterIds = {}

        # Add clusters if they are not already on the map
        for cluster in clusters
          dataClusterIds[cluster.id] = cluster.id
          createCluster(cluster) unless window.clusters[cluster.id]

        # Determine which clusters need to be removed from the map
        toRemove = []
        for clusterId, cluster of window.clusters
          unless dataClusterIds[clusterId]
            toRemove.push clusterId

        # And remove them
        window.deleteCluster clusterId for clusterId in toRemove
      else
        toRemove = []
        for clusterId, cluster of window.clusters
          toRemove.push clusterId

        window.deleteCluster clusterId for clusterId in toRemove

        window.createCluster(cluster) for cluster in clusters

      window.reuseCurrentClusters = true

      callback() if callback && typeof(callback) == 'function'

    if query.collection_ids.length == 0
      # Save a request to the server if there are no selected collections
      getCallback()
    else
      $.get "/sites/search.json", query, getCallback

  window.setAllMarkersInactive = ->
    currentSiteId = window.model.currentSite()?.id()
    currentSiteId = (currentSiteId).toString() if currentSiteId
    for siteId, marker of window.markers
      if currentSiteId == siteId
        window.setMarkerIcon marker, 'target'
      else
        window.setMarkerIcon marker, 'inactive'

  window.setAllMarkersActive = ->
    selectedSiteId = window.model.selectedSite()?.id()
    selectedSiteId = (selectedSiteId).toString() if selectedSiteId
    for siteId, marker of window.markers
      if selectedSiteId == siteId
        window.setMarkerIcon marker, 'target'
      else
        window.setMarkerIcon marker, 'active'

  window.setMarkerIcon = (marker, icon) ->
    switch icon
      when 'active'
        marker.setIcon null
        marker.setShadow null
      when 'inactive'
        marker.setIcon window.markerImageInactive
        marker.setShadow window.markerImageInactiveShadow
      when 'target'
        marker.setIcon window.markerImageTarget
        marker.setShadow window.markerImageTargetShadow

  window.setupMarkerListener = (site, marker) ->
    window.markerListener = google.maps.event.addListener marker, 'position_changed', =>
      site.position(marker.getPosition())

  window.deleteMarker = (siteId) ->
    if siteId
      if window.markers[siteId]
        window.markers[siteId].setMap null
        delete window.markers[siteId]
    else if window.marker
      window.marker.setMap null
      delete window.marker

  window.deleteMarkerListener = ->
    if window.markerListener
      google.maps.event.removeListener window.markerListener
      delete window.markerListener

  window.createCluster = (cluster) ->
    window.clusters[cluster.id] = new Cluster
                                    map: window.map
                                    position: new google.maps.LatLng(cluster.lat, cluster.lng)
                                    count: cluster.count

  window.deleteCluster = (id) ->
    window.clusters[id].setMap null
    delete window.clusters[id]

  Cluster = (options) ->
    @position = options.position
    @count = options.count
    @setMap options.map

  Cluster.prototype = new google.maps.OverlayView

  Cluster.prototype.onAdd = ->
    @div = document.createElement 'DIV'
    @div.style.border = "none"
    @div.style.borderWidth = "0px"
    @div.style.display = "table-cell"
    @div.style.position = "absolute"
    @div.style.textAlign = 'center'
    @div.style.fontSize = '11px'
    @div.style.cursor = 'pointer'
    @div.innerText = (@count).toString()

    if @count < 10
      @image = 1
      @width = 53
      @height = 52
    else if @count < 25
      @image = 2
      @width = 56
      @height = 55
    else if @count < 50
      @image = 3
      @width = 66
      @height = 65
    else if @count < 100
      @image = 4
      @width = 78
      @height = 77
    else
      @image = 5
      @width = 90
      @height = 89

    @div.style.backgroundImage = "url('http://google-maps-utility-library-v3.googlecode.com/svn/trunk/markerclusterer/images/m#{@image}.png')"
    @div.style.width = "#{@width}px"
    @div.style.height = @div.style.lineHeight = "#{@height}px"

    panes = this.getPanes()
    panes.overlayMouseTarget.appendChild @div

    @listener = google.maps.event.addDomListener @div, 'click', =>
      window.map.panTo(@position)
      window.map.setZoom(window.map.getZoom() + 1)

  Cluster.prototype.draw = ->
    overlayProjection = @getProjection()
    pos = overlayProjection.fromLatLngToDivPixel @position
    @div.style.left = "#{pos.x - @width / 2}px"
    @div.style.top = "#{pos.y - @height / 2}px"

  Cluster.prototype.onRemove = ->
    google.maps.event.removeListener @listener
    @div.parentNode.removeChild @div
    @div = null


  class Field
    constructor: (data) ->
      @code = ko.observable data?.code
      @name = ko.observable data?.name
      @kind = ko.observable data?.kind
      @value = ko.observable()

  class SitesContainer
    constructor: (data) ->
      @id = ko.observable data?.id
      @name = ko.observable data?.name
      @sites = ko.observableArray()
      @expanded = ko.observable false
      @sitesPage = 1
      @hasMoreSites = ko.observable true
      @loadingSites = ko.observable false
      @siteIds = {}

    loadMoreSites: (callback) =>
      if @hasMoreSites()
        @loadingSites true
        # Fetch more sites. We fetch one more to know if we have more pages, but we discard that
        # extra element so the user always sees SITES_PER_PAGE elements.
        $.get @sitesUrl(), {offset: (@sitesPage - 1) * SITES_PER_PAGE, limit: SITES_PER_PAGE + 1}, (data) =>
          @sitesPage += 1
          if data.length == SITES_PER_PAGE + 1
            data.pop()
          else
            @hasMoreSites false
          for site in data
            @addSite new Site(this, site)
          @loadingSites false
          callback() if callback && typeof(callback) == 'function'
      else
        callback() if callback && typeof(callback) == 'function'

    addSite: (site) =>
      unless @siteIds[site.id()]
        @sites.push(site)
        @siteIds[site.id()] = site

    toggle: =>
      # Load more sites when we expand, but only the first time
      if @group() && !@expanded() && @hasMoreSites() && @sitesPage == 1
        @loadMoreSites()
      @expanded(!@expanded())

  class Collection extends SitesContainer
    constructor: (data) ->
      super
      @class = 'Collection'
      @fields = ko.observableArray()
      @checked = ko.observable true
      @fieldsInitialized = false

    sitesUrl: -> "/collections/#{@id()}/sites"

    level: -> 0

    fetchLocation: =>

    fetchFields: =>
      unless @fieldsInitialized
        @fieldsInitialized = true
        $.get "/collections/#{@id()}/fields", {}, (data) =>
          @fields $.map(data, (x) => new Field(x))

    findFieldByCode: (code) =>
      (field for field in @fields() when field.code() == code)[0]

  class Site extends SitesContainer
    constructor: (parent, data) ->
      super
      @class = 'Site'
      @parent = parent
      @selected = ko.observable()
      @id = ko.observable data?.id
      @parent_id = ko.observable data?.parent_id
      @group = ko.observable data?.group
      @name = ko.observable data?.name
      @lat = ko.observable data?.lat
      @lng = ko.observable data?.lng
      @locationMode = ko.observable data?.location_mode
      @position = ko.computed
        read: =>
          if @lat() && @lng()
            new google.maps.LatLng(@lat(), @lng())
          else
            null

        write: (latLng) =>
          @lat(latLng.lat())
          @lng(latLng.lng())

        owner: @
      @properties = ko.observable data?.properties
      @hasFocus = ko.observable false

    sitesUrl: -> "/sites/#{@id()}/root_sites"

    level: =>
      @parent.level() + 1

    hasLocation: =>
      @position() && !(@group() && @locationMode() == 'none')

    fetchLocation: =>
      $.get "/sites/#{@id()}.json", {}, (data) => @lat(data.lat); @lng(data.lng)
      @parent.fetchLocation()

    copyPropertiesFromCollection: (collection) =>
      @properties({})
      for field in collection.fields()
        @properties()[field.code()] = field.value()

    copyPropertiesToCollection: (collection) =>
      if @properties()
        for key, value of @properties()
          collection.findFieldByCode(key).value(value)

    toJSON: =>
      json =
        id: @id()
        group: @group()
        name: @name()
      json.lat = @lat() if @lat()
      json.lng = @lng() if @lng()
      json.parent_id = @parent_id() if @parent_id()
      json.properties = @properties() if @properties()
      json.location_mode = @locationMode() if @locationMode()
      json

  class CollectionViewModel
    constructor: ->
      self = this

      @collections = ko.observableArray $.map(initialCollections, (x) -> new Collection(x))
      @currentCollection = ko.observable()
      @currentParent = ko.observable()
      @currentSite = ko.observable()
      @selectedSite = ko.observable()

      @currentCollection.subscribe (newValue) ->
        newValue.loadMoreSites() if newValue && newValue.sitesPage == 1
        window.reloadMapSites() if window.navigated

      $.each @collections(), (idx) =>
        @collections()[idx].checked.subscribe (newValue) =>
          window.reuseCurrentClusters = false
          window.reloadMapSites()

      Sammy( ->
        @get '#:collection', ->
          self.currentCollection self.findCollectionById(parseInt this.params.collection)
          self.currentCollection().fetchFields()

        @get '', ->
          self.currentCollection(null)
      ).run()

    findCollectionById: (id) =>
      (x for x in @collections() when x.id() == id)[0]

    goToRoot: ->
      window.navigated = true
      window.reuseCurrentClusters = false
      location.hash = ''

    enterCollection: (collection) ->
      window.navigated = true
      window.reuseCurrentClusters = false
      location.hash = "#{collection.id()}"

    editCollection: (collection) ->
      window.location = "/collections/#{collection.id()}"

    createCollection: ->
      window.location = "/collections/new"

    createGroup: =>
      @createSiteOrGroup true

    createSite: =>
      @createSiteOrGroup false

    createSiteOrGroup: (group) =>
      parent = if @selectedSite() then @selectedSite() else @currentCollection()
      pos = window.map.getCenter()
      site = if group
               new Site(parent, parent_id: @selectedSite()?.id(), lat: pos.lat(), lng: pos.lng(), group: group, location_mode: 'auto')
             else
               new Site(parent, parent_id: @selectedSite()?.id(), lat: pos.lat(), lng: pos.lng(), group: group)
      site.hasFocus true
      @currentSite site

      # Add a marker to the map for setting the site's position
      if group
        @subscribeToLocationModeChange site
      else
        @createMarkerForSite site

    createMarkerForSite: (site, drop = false) =>
      window.marker = new google.maps.Marker
        position: site.position()
        animation: if drop || !site.id() then google.maps.Animation.DROP else null
        draggable: true
        icon: window.markerImageTarget
        shadow: window.markerImageTargetShadow
        map: window.map
      window.setupMarkerListener site, window.marker
      window.setAllMarkersInactive()

    subscribeToLocationModeChange: (site) =>
      window.subscription = site.locationMode.subscribe (newLocationMode) =>
        if newLocationMode == 'manual'
          @createMarkerForSite site, true
        else
          window.deleteMarker()
          window.deleteMarkerListener()

    unsubscribeToLocationModeChange: =>
      if window.subscription
        window.subscription.dispose()
        delete window.subscription

    editSite: (site) =>
      site.copyPropertiesToCollection(@currentCollection())
      site.hasFocus true
      @currentSite(site)
      @selectedSite(site)

      # Pan the map to it's location
      window.reloadMapSitesAutomatically = false
      window.reuseCurrentClusters = false
      window.deleteMarker site.id()
      window.map.panTo(site.position()) if site.hasLocation()
      window.reloadMapSites =>
        window.reloadMapSitesAutomatically = true

        # Add a marker to the map for setting the site's position
        if !site.group() || (site.group() && site.locationMode() == 'manual')
          @createMarkerForSite site
        if site.group()
          @subscribeToLocationModeChange site

    exitSite: =>
      @unsubscribeToLocationModeChange()
      @currentSite(null)
      window.deleteMarker()
      window.deleteMarkerListener()
      window.setAllMarkersActive()
      window.reuseCurrentClusters = false
      window.reloadMapSites()

    saveSite: =>
      callback = (data) =>
        unless @currentSite().id()
          @currentSite().id(data.id)
          if @selectedSite()
            @selectedSite().addSite(@currentSite())
          else
            @currentCollection().addSite(@currentSite())

        # If lat/lng/locationMode changed, update parent locations from server
        if @currentSite().lat() != data.lat || @currentSite().lng() != data.lng || (@currentSite().group() && @currentSite().locationMode() != data.location_mode)
          @currentSite().parent.fetchLocation()

        @currentSite().lat(data.lat)
        @currentSite().lng(data.lng)

        @exitSite()

      unless @currentSite().group()
        @currentSite().copyPropertiesFromCollection(@currentCollection())

      json = {site: @currentSite().toJSON()}

      if @currentSite().id()
        json._method = 'put'
        $.post "/collections/#{@currentCollection().id()}/sites/#{@currentSite().id()}.json", json, callback
      else
        $.post "/collections/#{@currentCollection().id()}/sites", json, callback

    selectSite: (site) =>
      if @selectedSite() == site
        if !site.group() && window.markers[site.id()]
          window.setMarkerIcon window.markers[site.id()], 'active'
        @selectedSite().selected(false)
        @selectedSite(null)
      else
        oldSiteId = @selectedSite()?.id()
        @selectedSite().selected(false) if @selectedSite()
        @selectedSite(site)
        @selectedSite().selected(true)
        if @selectedSite().id() && @selectedSite().hasLocation()
          window.map.panTo(@selectedSite().position())
          window.reloadMapSites =>
            if oldSiteId && window.markers[oldSiteId]
              window.setMarkerIcon window.markers[oldSiteId], 'active'
            if !@selectedSite().group() && window.markers[@selectedSite().id()]
              window.setMarkerIcon window.markers[@selectedSite().id()], 'target'

    toggleSite: (site) =>
      site.toggle()

  window.markers = {}
  window.clusters = {}
  window.reloadMapSitesAutomatically = true
  window.reuseCurrentClusters = true
  window.requestNumber = 0

  myOptions =
    center: new google.maps.LatLng(10, 90)
    zoom: 4
    mapTypeId: google.maps.MapTypeId.ROADMAP
  window.map = new google.maps.Map document.getElementById("map"), myOptions

  window.model = new CollectionViewModel

  listener = google.maps.event.addListener window.map, 'bounds_changed', ->
    google.maps.event.removeListener listener
    window.reloadMapSites ->
      ko.applyBindings window.model

  google.maps.event.addListener window.map, 'dragend', -> window.reloadMapSites()
  google.maps.event.addListener window.map, 'zoom_changed', ->
    listener2 = google.maps.event.addListener window.map, 'bounds_changed', ->
      google.maps.event.removeListener listener2
      window.reloadMapSites() if window.reloadMapSitesAutomatically
