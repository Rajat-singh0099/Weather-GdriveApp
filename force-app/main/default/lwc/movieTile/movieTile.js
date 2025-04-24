import { LightningElement, api } from 'lwc';

export default class MovieTile extends LightningElement {
    @api movie;
    @api selectedMovieId;

    clickHandler(){
        console.log(this.movie.imdbID);
        //customEvents
        //1. create the event.
        const evt = new CustomEvent("selectedmovie",{
            detail: this.movie.imdbID
        });

        //2. Dispatch the event.
        this.dispatchEvent(evt);
    }

    get tileSelected(){
        return this.selectedMovieId === this.movie.imdbID ? "tile selected" : "tile";
    }
}