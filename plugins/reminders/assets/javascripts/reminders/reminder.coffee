onReminders ->
  class @Reminder 
    constructor: (data) ->
      @id = ko.observable data?.id
      @name = ko.observable data?.name
      seperator = ''
      if data.reminder_date?.indexOf("T") > 0
        seperator = 'T'
      else
        seperator = ' '
      @reminder_date = ko.observable data?.reminder_date?.split(seperator)[0]
      @reminder_time = ko.observable data?.reminder_date?.split(seperator)[1].substring(0,5)
      @reminder_datetime = ko.computed =>
        @reminder_date() + " " + @reminder_time()
      @reminder_message = ko.observable data?.reminder_message
      @repeat = ko.observable window.model.findRepeat(data?.repeat_id)

      @collection_id = ko.observable data?.collection_id
      @is_all_site = ko.observable data?.is_all_site?.toString() ? "true"
      
      if @is_all_site() == "true"
        @sites = ko.observableArray []
      else
        @sites = ko.observableArray $.map(data?.sites ? [], (site) -> new Site(site))
      
      @nameError = ko.computed =>
        if $.trim(@name()).length > 0 
          return null
        else
          return "Reminder's name is missing"
      @sitesError = ko.computed =>
        return if @is_all_site() == "false" and @sites().length == 0 then "Sites is missing" else null
        # if @sites().length > 0
          # return null
        # else
          # return "Sites is missing"
      @reminderDateError =ko.computed =>
        if $.trim(@reminder_date()).length > 0
          return null
        else
          return "Reminder's date is missing"

      @reminderMessageError = ko.computed =>
        if $.trim(@reminder_message()).length > 0
          return null
        else
          return "Reminder's message is missing"

      @error = ko.computed =>
        errorMessage = @nameError() || @sitesError() || @reminderDateError() || @reminderMessageError()
        # errorMessage = @nameError() || @reminderDateError() || @reminderMessageError()
        if errorMessage then "Can't save: " + errorMessage else ""

      @valid = ko.computed => !@error()
      
    toJSON: =>
      id: @id()
      name: @name()
      reminder_date: @reminder_datetime()
      reminder_message: @reminder_message()
      repeat_id: @repeat().id()
      collection_id: @collection_id()
      is_all_site: @is_all_site()
      sites: $.map(@sites(), (x) -> x.id) if @is_all_site() == "false"

    toReminderJSON: =>
      id: @id()
      name: @name()
      reminder_date: @reminder_datetime()
      reminder_message: @reminder_message()
      repeat_id: @repeat().id()
      repeat: @repeat().toJSON()
      collection_id: @collection_id()
      is_all_site: @is_all_site()
      sites: $.map(@sites(), (site) -> site.toJSON()) if @is_all_site() == "false"

    getSitesRepeatLabel: =>
      sites = if @is_all_site() == "true" then ["all sites"] else $.map @sites(), (site) => site.name
      detail = @repeat().name() + " for " + sites.join(",")
        
