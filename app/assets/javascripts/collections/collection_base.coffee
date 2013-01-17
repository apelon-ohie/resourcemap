#= require module
#= require collections/locatable
#= require collections/sites_container
#= require collections/sites_membership
#= require collections/layer
#= require collections/field
onCollections ->

  class @CollectionBase extends Module
    @include Locatable
    @include SitesContainer
    @include SitesMembership

    constructor: (data) ->
      @constructorLocatable(data)
      @constructorSitesContainer()
      @constructorSitesMembership()

      @id = data?.id
      @name = data?.name
      @is_admin = data?.is_admin
      @currentSnapshot = if data?.snapshot_name then data?.snapshot_name else ''
      @updatedAt = ko.observable(data.updated_at)
      @updatedAtTimeago = ko.computed => if @updatedAt() then $.timeago(@updatedAt()) else ''
      @loadCurrentSnapshotMessage()
      @loadAllSites()

    loadAllSites: =>
      @allSites = ko.observable()

    findSiteNameById: (value) =>
      allSites = window.model.currentCollection().allSites()
      return if not allSites
      (site.name for site in allSites when site.id is parseInt(value))[0]

    findSiteIdByName: (value) =>
      id = (site for site in window.model.currentCollection().allSites() when site.name is value)[0]?.id
      id

    loadCurrentSnapshotMessage: =>
      @viewingCurrentSnapshotMessage = ko.observable()
      @viewingCurrentSnapshotMessage("You are currently viewing this collection's data as it was on snapshot " + @currentSnapshot + ".")

    fetchFields: (callback) =>
      if @fieldsInitialized
        callback() if callback && typeof(callback) == 'function'
        return

      @fieldsInitialized = true
      $.get "/collections/#{@id}/fields", {}, (data) =>
        @layers($.map(data, (x) => new Layer(x)))

        fields = []
        for layer in @layers()
          for field in layer.fields
            fields.push(field)

        @fields(fields)
        @refineFields(fields)
        @refineFields.sort (f1, f2) ->
          lowerF1 = f1.name.toLowerCase()
          lowerF2 = f2.name.toLowerCase()
          if lowerF1 == lowerF2 then 0 else (if lowerF1 > lowerF2 then 1 else -1)
        callback() if callback && typeof(callback) == 'function'

    findFieldByEsCode: (esCode) => (field for field in @fields() when field.esCode == esCode)[0]

    clearFieldValues: =>
      field.value(null) for field in @fields()

    propagateUpdatedAt: (value) =>
      @updatedAt(value)

    link: (format) => "/api/collections/#{@id}.#{format}"

    level: => -1

    setQueryParams: (q) -> q

    performHierarchyChanges: (site, changes) =>

    sitesWithoutLocation: ->
      res = (site for site in this.sites() when !site.hasLocation())
      res

    unloadCurrentSnapshot: ->
      $.post "/collections/#{@id}/unload_current_snapshot.json", ->
        window.location.reload()

