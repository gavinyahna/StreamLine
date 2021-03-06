// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require interactjs
//= require jquery
//= require jquery-ui
//= require rails-ujs
//= require activestorage
//= require turbolinks
//= require daterangepicker
//= require_tree .
//= require_self

// fullCalendar setup

var initialize_calendar;
initialize_calendar = function() {
  $('#calendar_body').each(function(){
    var calendar = $(this);
    calendar.fullCalendar({
        header: {
            left: 'prev,next,today',
            center: 'title',
            right: 'month,agendaWeek,agendaDay',
            },
            defaultView: 'agendaWeek',
            selectable: true,
            selectHelper: true,
            editable: true,
            droppable: true,
            eventLimit: true,
            height: "auto",
            handleWindowResize: true,
            titleFormat: 'MMMM YYYY',
            minTime: '06:00:00', // Start time for the calendar
            maxTime: '25:30:00', // End time for the calendar
            columnHeaderFormat: 'ddd D',
            displayEventTime: true, // Display event time
            events: '/tasks.json',

            select: function(start, end) {
              $.getScript('/tasks/new', function() {
                $('#task_date_range').val(moment(start).format("MM/DD/YYYY HH:mm") + ' - ' + moment(end).format("MM/DD/YYYY HH:mm"))
                date_range_picker();
                $('.start_hidden').val(moment(start).format('YYYY-MM-DD HH:mm'));
                $('.end_hidden').val(moment(end).format('YYYY-MM-DD HH:mm'));
              });
      
              calendar.fullCalendar('unselect');
            },
      
            eventDrop: function(event, delta, revertFunc) {
              if (!event.end)
                end = event.start
              else
                end = event.end
              event_data = { 
                task: {
                  id: event.id,
                  title: event.title,
                  start: event.start.format(),
                  end: end.format(),
                }
              };
              $.ajax({
                  url: event.update_url,
                  data: event_data,
                  type: 'PATCH'
              });
            },

            drop: function(date) {
              event_data = {
                task: {
                  note_id: this.id,
                  start: date.format(),
                  end: date.add(1, 'hours').format()
                }
              }
              $.ajax({
                url: '/tasks',
                data: event_data,
                type: 'POST',
                async: false
              });
              $.ajax({
                url: '/notes/' + this.id,
                type: 'DELETE'
              });
              this.remove();
            },

            eventResize: function(event, delta, revertFunc) {
              event_data = { 
                task: {
                  id: event.id,
                  title: event.title,
                  start: event.start.format(),
                  end: event.end.format()
                }
              };
              $.ajax({
                  url: event.update_url,
                  data: event_data,
                  type: 'PATCH'
              });
            },
            
            eventClick: function(event, jsEvent, view) {
              $.getScript(event.edit_url, function() {
                $('#task_date_range').val(moment(event.start).format("MM/DD/YYYY HH:mm") + ' - ' + moment(event.end).format("MM/DD/YYYY HH:mm"))
                date_range_picker();
                $('.start_hidden').val(moment(event.start).format('YYYY-MM-DD HH:mm'));
                $('.end_hidden').val(moment(event.end).format('YYYY-MM-DD HH:mm'));
              });
            }
          });
        })
      };
$(document).on('turbolinks:load', initialize_calendar);

// fullCalendar date picker

var date_range_picker;
date_range_picker = function() {
  $('.date-range-picker').each(function(){
    $(this).daterangepicker({
        hours12: true,
        autoApply: true,
        timePicker: true,
        timePickerIncrement: 5,
        alwaysShowCalendars: true,
        locale: {
          format: 'M/DD hh:mm A'
        }
    }, function(start, end, label) {
      $('.start_hidden').val(start.format('YYYY-MM-DD HH:mm'));
      $('.end_hidden').val(end.format('YYYY-MM-DD HH:mm'));
    });
  })
};
$(document).on('turbolinks:load', date_range_picker);

// dragging and dropping notes

$(document).ready(function () {
    doDraggable();
});

function doDraggable() {
  $(".note").draggable({
    helper: 'clone',
    appendTo: 'body',
    start: function (event, ui) {
      var w = $(this).css('width');
      var h = $(this).css('height');
      ui.helper.css('width', w).css('height', h);
    }
  });
  
  $("#note_grid").droppable({
    accept: ".note",
  });
}

// handeling opening and closing notes

$(document).click(function(event) { 
  if($(event.target).hasClass('noClick')){
    $(event.target).removeClass('noClick');
    console.log(event.target);
  }else{
    console.log("current Target: ",event.currentTarget);
    
    newNote = document.getElementsByClassName('new_note');
    console.log(newNote.length > 0);
    if(newNote.length > 0){
      click_outside_element_handler(event); 
    }
    if($(event.target).hasClass("note")){
      console.log("target: ", event.target);
      note_click_event_handler(event);
    }
  }
});

var click_outside_element_handler = function(event) {
    if(!$(event.target).closest('.new_note').length) {
      note_form = document.getElementById('note_form');
      $.ajax({
        url: $(note_form).attr('action'),
        data: $(note_form).serialize(),
        type: 'PATCH',
        async: false
      });
    }       
}

var note_click_event_handler = function(event) {
  $.get("/notes/"+event.target.id, null, 'script');
}
