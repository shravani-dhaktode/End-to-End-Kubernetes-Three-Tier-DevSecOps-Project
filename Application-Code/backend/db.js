const mongoose = require("mongoose");

// Connects to MongoDB. If the database is not ready yet (common right after
// deploying to Kubernetes), it waits 5 seconds and tries again, forever.
const connect = async () => {
    try {
        const connectionParams = {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        };
        const useDBAuth = process.env.USE_DB_AUTH || false;
        if(useDBAuth){
            connectionParams.user = process.env.MONGO_USERNAME;
            connectionParams.pass = process.env.MONGO_PASSWORD;
        }
        await mongoose.connect(
           process.env.MONGO_CONN_STR,
           connectionParams
        );
        console.log("Connected to database.");
    } catch (error) {
        console.log("Could not connect to database. Retrying in 5 seconds...", error.message);
        setTimeout(connect, 5000);
    }
};

module.exports = connect;
