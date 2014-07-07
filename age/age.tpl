//Age-structured model for eastern NP blue whales. CCM 6/2012

// This model is from Breiwick et al 1984


  // ------------------------------------------------------------
DATA_SECTION

  // mceval report; i.e. this tells ADMB where to write the MCMC
  // output in this phase
  !!CLASS ofstream MCMCreport("MCMC.csv",ios::app);

  // These are the variables read in from "blue_age.dat" and won't
  // change. Below are some that I want to be able to control outside
  // of the model and thus are set in a control file.
  init_int num_years		// # of years to project the population
  init_vector catches(1,num_years) // catches in each year
  init_int num_obs		   // number of MRC estimates
  init_vector Y_years(1,num_obs)   // years of projection
  init_vector Y_obs(1,num_obs)	   // MRC abundance estimates
  init_vector Y_SD(1,num_obs)	   // SD of these estimates
  init_int max_age		   // age of maturity/plus group
  init_number z			   // fixed param in the model
  int j 			// a counter to be used later

  //  This reads in values from a control file and sets the following
  //  variables. Per Ian's recommendation, this can be used to run
  //  different tests with different parameters estimated without
  //  recompiling the model each time. I will also need to add a
  //  variable for choosing which priors to use (TODO).
  !! ad_comm::change_datafile_name("age.ctl");
  init_int phase_K; // phases for params
  init_int phase_r;
  init_int phase_S0;
  init_int phase_Splus;
  // ------------------------------------------------------------


  // ------------------------------------------------------------
INITIALIZATION_SECTION
  K 5000
  r .05
  S0 .8
  Splus .95
  // ------------------------------------------------------------


  // ------------------------------------------------------------
PARAMETER_SECTION
  init_bounded_number K(1000,10000,phase_K)  		// carrying capacity of 1+ animals
  init_bounded_number r(0,1,phase_r)		// max fecundity, i.e. @ 0 animals
  init_bounded_number S0(0,1,phase_S0) 		// survival of 0 age animals
  init_bounded_number Splus(0,1,phase_Splus)	// survival of 1+ animals
  matrix age_pred(1,num_years,1,max_age+1) // matrix of ages and years
  vector Nplus(1,num_years)		   // vector of 1+ animals for each year
  vector Y_final(1,num_obs)
  // used in intermediate calcs
  number fmax
  number f0
  number N0
  objective_function_value NLL
  sdreport_number Kreport
  // ------------------------------------------------------------


  // ------------------------------------------------------------
PROCEDURE_SECTION
  // Initialize basic params, note that j is just a counter for use in
  // subseting years in which there are abundance estimates. There is
  // probably a much better way to do this. In R it would be
  // Y_final[Y_years] which would then match up to Y_obs.
   j=1;
  NLL=0;

  // Initialize the age structured matrix. Remember that age 0
  // (calves) are in column 1, and likewise, so that all ages are
  // shifted by 1.
   f0=(1-Splus)/(pow(Splus,max_age-1)*S0);
   fmax=f0+r;
   N0=K*pow(Splus,max_age-1)*f0;
   age_pred(1,1)=N0;
   age_pred(1,2)=N0*S0;
   for(int i=3;i<=max_age; i++)  age_pred(1,i)=age_pred(1,i-1)*Splus;
   age_pred(1,max_age+1)=N0/f0;
   // Nplus is the age 1+ animals from the previous year, *not* the
   // plus group!

   // To calculate 1+ group sum the row and subtract off calves from
   // the row sum since they aren't counted in the 1+ group.
   Nplus(1)=sum(row(age_pred,1))-age_pred(1,1);

  // ---------------
   // The first row of the matrix is now ready to go and we can simply
   // loop through each year and make the necessary calculations.
   for(int y=2;y<=num_years;y++)
   {
   dvariable fpen=0.0;
   // the first two age classes still need special calcs, and need to
   // calculate the calves last, by assumption of the model
   age_pred(y,2)=age_pred(y-1,1)*S0; // no fishing pressure on these so no catches
   for(int age=3;age<=max_age+1;age++)
       {
          age_pred(y,age)=(age_pred(y-1,age-1)-
	             catches(y-1)*age_pred(y-1,age-1)/Nplus(y-1))*Splus;
       }
   // Account for the plus group in the last age class by adding the
   // previous plus group
   age_pred(y,max_age+1)+=(age_pred(y-1,max_age+1)-
          catches(y-1)*age_pred(y-1,max_age+1)/Nplus(y-1))*Splus;
   // I assume that calves are born at the end of the year so I need
   // to calculate them last
   Nplus(y)=posfun(sum(row(age_pred,y))-age_pred(y,1), 100, fpen);
   NLL+=10000*fpen;
   if(Nplus(y)<=0) cout << "negative biomass";
   age_pred(y,1)=age_pred(y,max_age+1)*(f0+(fmax-f0)*(1-pow(Nplus(y)/K,z)));
   // within the loop check if this is a year with an abundance
   // estimate and if so add to the NLL
       if(Y_years(j)==y)
         {
	 Y_final(j)=Nplus(y);
	  NLL+=pow(log(Y_obs(j))- log(Y_final(j)),2)/(2*Y_SD(j)*Y_SD(j));
	  j++;
        }
   } // end of loop through years

  // The matrix is now fully complete and the negative loglikelihood
  // is calculated. MLE part is complete.
  // ---------------


  // ---------------
  // Bayesian calculations

  // If desired, add the contribution of the priors to get a scaled
  // posterior. Note that not adding a prior implies uniform priors on
  // all parameters.
  NLL+= pow(r-.042,2)/(2*pow(.019,2)); // prior on r is normal (for now)
  NLL+= pow(S0-.8,2)/(2*pow(.1,2)); // prior on S0 is normal (for now)
  NLL+= pow(Splus-.9,2)/(2*pow(.1,2)); // prior on S0 is normal (for now)
  //cout << Nplus(num_years) << "," << NLL << endl;

  // If in MCMC phase, print out the variable values (i.e. this is one iteration)
 if(mceval_phase())
   {
     MCMCreport << K << "," << r << "," << S0 << "," << Splus << endl;
   }
 // end of Bayesian part
 // ---------------
 // ------------------------------------------------------------


 // ------------------------------------------------------------
 // REPORT_SECTION
 //  report << "Y" << endl << Y_final << endl;
 // ------------------------------------------------------------
 // End of file
