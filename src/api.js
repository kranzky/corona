dimmer = $('.ui.dimmer');

function loadPage() {
  $('#region').dropdown({ onChange: selectRegion });
  $('#subregion').dropdown({ onChange: selectSubregion });
  $('#country').dropdown({ onChange: selectCountry });
  $('#state').dropdown({ onChange: selectState });
  $('#city').dropdown({ onChange: selectCity });
  loadRegions("https://corona.kranzky.com/api.json");
}

function loadRegions(uri) {
  $('#region').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#region .menu').empty();
      refreshDisplay(uri, response.data, response.request.responseText);
      if (!_.isEmpty(response.data.regions)) {    
        _.each(response.data.regions, function(value) {
          $('#region .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#region').show();
      }
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadSubregions(uri) {
  $('#subregion').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#subregion .menu').empty();
      refreshDisplay(uri, response.data, response.request.responseText);
      if (!_.isEmpty(response.data.subregions)) {    
        _.each(response.data.subregions, function(value) {
          $('#subregion .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#subregion').show();
      }
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadCountries(uri) {
  $('#country').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#country .menu').empty();
      refreshDisplay(uri, response.data, response.request.responseText);
      if (!_.isEmpty(response.data.countries)) {    
        _.each(response.data.countries, function(value) {
          $('#country .menu').append(`<div class="item" data-value="${value.uri}"><i class="${value.id.toLowerCase()} flag"></i>${value.name}</div>`);
        });
        $('#country').show();
      }
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadStates(uri) {
  $('#state').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#state .menu').empty();
      refreshDisplay(uri, response.data, response.request.responseText);
      if (!_.isEmpty(response.data.states)) {    
        _.each(response.data.states, function(value) {
          $('#state .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#state').show();
      }
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadCities(uri) {
  $('#city').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#city .menu').empty();
      refreshDisplay(uri, response.data, response.request.responseText);
      if (!_.isEmpty(response.data.cities)) {    
        _.each(response.data.cities, function(value) {
          $('#cities .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#city').show();
      }
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadResults(uri) {
  axios.get(uri)
    .then(function (response) {
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function selectRegion(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#subregion').hide();
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  loadSubregions(uri);
}

function selectSubregion(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  loadCountries(uri);
}

function selectCountry(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#state').hide();
  $('#city').hide();
  loadStates(uri);
}

function selectState(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#city').hide();
  loadCities(uri);
}

function selectCity(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  loadResults(uri);
}
