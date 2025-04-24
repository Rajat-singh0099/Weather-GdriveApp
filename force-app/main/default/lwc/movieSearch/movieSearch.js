import { LightningElement } from 'lwc';
const DELAY = 300;
export default class MovieSearch extends LightningElement {
    selectedType = "";
    selectedSearch = "";
    loading = false;
    selectedPageNo = "1";
    delayTimeout;
    searchResult = [];
    selectedMovie = "";

    get typeoptions() {
        return [
            { label: 'None', value: '' },
            { label: 'Movie', value: 'movie' },
            { label: 'Series', value: 'series' },
            { label: 'Episode', value: 'episode' },
        ];
    }

    handleChange(event){
        let {name, value} = event.target;
        this.loading = true;
        if(name ===  'type'){
            this.selectedType = value;
        }else if (name === 'search'){
            this.selectedSearch = value;
        }else if(name === 'pageno'){
            this.selectedPageNo = value;
        }

        //debouncing
        clearTimeout(this.delayTimeout);
        this.delayTimeout = setTimeout(() => {
            this.searchMovie();
        }, DELAY);

    }

    async searchMovie(){
        const url = `https://www.omdbapi.com/?s=${this.selectedSearch}&type=${this.selectedType}&page=${this.selectedPageNo}&apikey=725d3b83`;
        const response = await fetch(url);
        const data = await response.json();
        console.log("Movie Output", data);
        this.loading = false;
        if(data.Response === 'True'){
            this.searchResult = data.Search;
        }
    }

    movieSelectedHandler(event){
        this.selectedMovie = event.detail;
    }

    get displaySearchResult(){
        return this.searchResult.length > 0 ? true : false;
    }

}