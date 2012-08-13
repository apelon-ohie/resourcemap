describe 'Collection', ->
  beforeEach ->
    window.runOnCallbacks 'collections'

    window.model = new MainViewModel
    @collection = new Collection id: 1
    window.model.initialize [@collection]
    @model = window.model

  describe 'MapViewModel', ->
    beforeEach ->
      @marker = new google.maps.Marker
      spyOn(@marker, 'setIcon')
      spyOn(@marker, 'setShadow')
      @model = window.model

    it 'should set marker icon to null', ->
      @model.setMarkerIcon @marker, 'null'
      expect(@marker.setIcon).toHaveBeenCalledWith(null)
      expect(@marker.setShadow).toHaveBeenCalledWith(null)

    it 'should include selected_hierarchy id in sites query', ->
      sw = new google.maps.LatLng(34, 0, false)
      ne = new google.maps.LatLng(22, 10, false)
      bounds = new google.maps.LatLngBounds(sw, ne)

      field = new Field { id: 1, code: 'admu', name: 'Admin Unit', kind: 'select_one', writeable: true }
      col_hierarchy = new CollectionHierarchy(@collection, field)
      hierarchyItem = new HierarchyItem(col_hierarchy, field, { id: 1, label: 'group 1' })

      query_before = @model.generateQueryParams(bounds, [1], 1)

      expect(query_before.selected_hierarchy).toBe(undefined)

      @model.selectHierarchy(hierarchyItem)
      query = @model.generateQueryParams(bounds, [1], 1)

      expect(query.selected_hierarchy).toEqual 1
